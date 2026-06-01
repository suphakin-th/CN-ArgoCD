"""
python-service — FastAPI REST gateway that proxies to go-service via gRPC.
Exposes /healthz, /ready, /metrics, and /api/v1/greet.
"""

import os
import time
import logging
import grpc
from contextlib import asynccontextmanager

import greet_pb2
import greet_pb2_grpc
from fastapi import FastAPI, HTTPException, Request
from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.grpc import GrpcInstrumentorClient
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response

logging.basicConfig(
    level=logging.INFO,
    format='{"time":"%(asctime)s","level":"%(levelname)s","msg":"%(message)s"}',
)
logger = logging.getLogger(__name__)

START_TIME = time.time()
VERSION = os.getenv("SERVICE_VERSION", "0.1.0")
GO_SERVICE_ADDR = os.getenv("GO_SERVICE_ADDR", "go-service:9090")
OTLP_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "tempo.monitoring:4317")

REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency",
    ["endpoint"],
)


def init_tracing():
    resource = Resource.create({"service.name": "python-service", "service.version": VERSION})
    provider = TracerProvider(resource=resource)
    exporter = OTLPSpanExporter(endpoint=OTLP_ENDPOINT, insecure=True)
    provider.add_span_processor(BatchSpanProcessor(exporter))
    trace.set_tracer_provider(provider)
    GrpcInstrumentorClient().instrument()


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_tracing()
    logger.info("python-service started", extra={"version": VERSION})
    yield
    logger.info("python-service shutting down")


app = FastAPI(title="python-service", version=VERSION, lifespan=lifespan)
FastAPIInstrumentor.instrument_app(app)


def get_grpc_stub():
    channel = grpc.insecure_channel(GO_SERVICE_ADDR)
    return greet_pb2_grpc.GreeterServiceStub(channel)


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start
    REQUEST_COUNT.labels(request.method, request.url.path, response.status_code).inc()
    REQUEST_LATENCY.labels(request.url.path).observe(duration)
    return response


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/ready")
def ready():
    try:
        stub = get_grpc_stub()
        stub.GetStatus(greet_pb2.StatusRequest(), timeout=2)
        return {"status": "ready", "upstream": "go-service:ok"}
    except grpc.RpcError:
        raise HTTPException(status_code=503, detail="upstream go-service unavailable")


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/api/v1/greet/{name}")
def greet(name: str, request: Request):
    tracer = trace.get_tracer("python-service")
    with tracer.start_as_current_span("greet-via-grpc") as span:
        span.set_attribute("name", name)
        try:
            stub = get_grpc_stub()
            resp = stub.SayHello(
                greet_pb2.HelloRequest(name=name, trace_id=str(span.get_span_context().trace_id)),
                timeout=5,
            )
            return {
                "message": resp.message,
                "upstream_service": resp.service,
                "upstream_version": resp.version,
                "timestamp": resp.timestamp,
            }
        except grpc.RpcError as e:
            logger.error("gRPC call failed: %s", e)
            raise HTTPException(status_code=502, detail="upstream error")


@app.get("/api/v1/info")
def info():
    return {
        "service": "python-service",
        "version": VERSION,
        "uptime_seconds": int(time.time() - START_TIME),
        "upstream": GO_SERVICE_ADDR,
    }
