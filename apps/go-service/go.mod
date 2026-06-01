module github.com/suphakin-th/CN-ArgoCD/apps/go-service

go 1.22

require (
	github.com/prometheus/client_golang v1.19.1
	go.opentelemetry.io/otel v1.27.0
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc v1.27.0
	go.opentelemetry.io/otel/sdk v1.27.0
	go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc v0.52.0
	google.golang.org/grpc v1.64.0
	google.golang.org/protobuf v1.34.2
)
