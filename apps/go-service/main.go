package main

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	pb "github.com/suphakin-th/CN-ArgoCD/apps/go-service/proto/greeterv1"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.25.0"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
)

var (
	version   = "0.1.0"
	startTime = time.Now()

	grpcRequestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "grpc_requests_total",
		Help: "Total number of gRPC requests by method and status.",
	}, []string{"method", "status"})

	grpcDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "grpc_request_duration_seconds",
		Help:    "gRPC request latency in seconds.",
		Buckets: prometheus.DefBuckets,
	}, []string{"method"})
)

type greeterServer struct {
	pb.UnimplementedGreeterServiceServer
}

func (s *greeterServer) SayHello(ctx context.Context, req *pb.HelloRequest) (*pb.HelloResponse, error) {
	timer := prometheus.NewTimer(grpcDuration.WithLabelValues("SayHello"))
	defer timer.ObserveDuration()

	slog.InfoContext(ctx, "SayHello called", "name", req.Name, "trace_id", req.TraceId)
	grpcRequestsTotal.WithLabelValues("SayHello", "ok").Inc()

	return &pb.HelloResponse{
		Message:   fmt.Sprintf("Hello, %s! From go-service v%s", req.Name, version),
		Service:   "go-service",
		Version:   version,
		Timestamp: time.Now().UnixMilli(),
	}, nil
}

func (s *greeterServer) GetStatus(ctx context.Context, _ *pb.StatusRequest) (*pb.StatusResponse, error) {
	return &pb.StatusResponse{
		Status:  "healthy",
		Version: version,
		Uptime:  int64(time.Since(startTime).Seconds()),
	}, nil
}

type healthServer struct{}

func (h *healthServer) Check(_ context.Context, _ *grpc_health_v1.HealthCheckRequest) (*grpc_health_v1.HealthCheckResponse, error) {
	return &grpc_health_v1.HealthCheckResponse{
		Status: grpc_health_v1.HealthCheckResponse_SERVING,
	}, nil
}

func (h *healthServer) Watch(_ *grpc_health_v1.HealthCheckRequest, _ grpc_health_v1.Health_WatchServer) error {
	return nil
}

func initTracer(ctx context.Context) (*sdktrace.TracerProvider, error) {
	endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if endpoint == "" {
		endpoint = "tempo.monitoring:4317"
	}

	exp, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(endpoint),
		otlptracegrpc.WithInsecure(),
	)
	if err != nil {
		return nil, err
	}

	res := resource.NewWithAttributes(
		semconv.SchemaURL,
		semconv.ServiceName("go-service"),
		semconv.ServiceVersion(version),
	)

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp),
		sdktrace.WithResource(res),
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
	)
	otel.SetTracerProvider(tp)
	return tp, nil
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer cancel()

	tp, err := initTracer(ctx)
	if err != nil {
		slog.Error("failed to init tracer", "error", err)
	} else {
		defer tp.Shutdown(context.Background())
	}

	grpcPort := envOrDefault("GRPC_PORT", "9090")
	httpPort := envOrDefault("HTTP_PORT", "8080")

	lis, err := net.Listen("tcp", ":"+grpcPort)
	if err != nil {
		slog.Error("failed to listen", "error", err)
		os.Exit(1)
	}

	grpcServer := grpc.NewServer(
		grpc.StatsHandler(otelgrpc.NewServerHandler()),
	)
	pb.RegisterGreeterServiceServer(grpcServer, &greeterServer{})
	grpc_health_v1.RegisterHealthServer(grpcServer, &healthServer{})
	reflection.Register(grpcServer)

	// HTTP server for /healthz, /ready, /metrics
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ok"}`))
	})
	mux.HandleFunc("/ready", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ready"}`))
	})
	mux.Handle("/metrics", promhttp.Handler())

	httpServer := &http.Server{Addr: ":" + httpPort, Handler: mux}

	go func() {
		slog.Info("gRPC server starting", "port", grpcPort)
		if err := grpcServer.Serve(lis); err != nil {
			slog.Error("gRPC server error", "error", err)
		}
	}()

	go func() {
		slog.Info("HTTP server starting", "port", httpPort)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("HTTP server error", "error", err)
		}
	}()

	<-ctx.Done()
	slog.Info("shutting down")
	grpcServer.GracefulStop()
	httpServer.Shutdown(context.Background())
}

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
