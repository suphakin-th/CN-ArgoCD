# CN-ArgoCD — Cloud-Native Platform on GKE

A multi-tenant Kubernetes platform on GCP managed entirely through Terraform and GitOps (ArgoCD). Everything from VPC provisioning to workload deployment is driven by code and git.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      GitHub (source of truth)                   │
│   terraform/  ->  GCP infra                                    │
│   argocd/     ->  ArgoCD App-of-Apps ->  Cluster sync        │
│   apps/       ->  Container images (GHCR) -> Deployments     │
└─────────────────────────────────────────────────────────────────┘

                        GCP Project: cn-fintech-gke
                        Region: asia-southeast1

  VPC (10.0.0.0/20)
  ├── Private GKE cluster (no public node IPs)
  │   ├── istio-system      → Istio control plane
  │   ├── argocd            → GitOps controller
  │   ├── monitoring        → Prometheus · Loki · Tempo · Grafana
  │   └── apps (mTLS)
  │       ├── go-service    → gRPC server (port 9090) + /metrics (8080)
  │       └── python-service → FastAPI REST (port 8000) → calls go-service
  └── Cloud NAT             → egress without public IPs
```

**Request path:**
```
Client → Istio Gateway (TLS) → python-service → gRPC → go-service
                                     ↓                       ↓
                              Prometheus /metrics     OTLP traces → Tempo
                              Promtail logs → Loki
```

---

## Repo layout

```
.github/workflows/
  terraform-ci.yml     tflint · tfsec · checkov on PR
  docker-build.yml     build, Trivy scan, push to GHCR on merge
  argocd-diff.yml      dry-run validate manifests on PR

terraform/
  modules/
    networking/        VPC · subnets · Cloud NAT · firewall
    gke/               private cluster · node pool · node SA
    iam/               Workload Identity bindings
    storage/           GCS buckets (state · loki · tempo)
  environments/
    dev/               e2-standard-2, 1–3 nodes
    prod/              e2-standard-4, 2–10 nodes

argocd/
  apps/
    app-of-apps.yaml   root Application (self-managing)
    platform-apps.yaml istio-base · istiod · monitoring-stack
    workload-apps.yaml go-service · python-service
  platform/
    namespaces.yaml    namespace definitions + istio-injection labels
    istio-gateway.yaml Gateway · VirtualServices · PeerAuthentication · DestinationRule

apps/
  go-service/          Go · gRPC · OpenTelemetry · distroless image
    proto/greeter.proto
    main.go
    k8s/               Deployment · Service · HPA · ServiceMonitor · PDB
  python-service/      Python · FastAPI · gRPC client · OTEL auto-instrumentation
    main.py
    k8s/               Deployment · Service · HPA · ServiceMonitor · PDB

monitoring/
  prometheus/values.yaml    kube-prometheus-stack
  prometheus/alerts.yaml    PrometheusRule CRDs
  loki/values.yaml          log aggregation → GCS
  tempo/values.yaml         distributed tracing → GCS
  dashboards/
    gke-cluster.json         node CPU · memory · pod counts
    app-latency.json         p50/p95/p99 · throughput · error rate
```

---

## Services

### go-service (Go · gRPC)

Implements `GreeterService` over gRPC. Also runs an HTTP server on `:8080` for health probes and `/metrics`.

- `SayHello(HelloRequest) → HelloResponse` — main RPC
- `GetStatus(StatusRequest) → StatusResponse` — used by the `/ready` probe
- Every RPC is wrapped with an OpenTelemetry span and a Prometheus histogram

### python-service (Python · FastAPI)

REST gateway that proxies to go-service over gRPC. Propagates trace context across the call boundary.

| Endpoint | Description |
|---|---|
| `GET /healthz` | Always 200 |
| `GET /ready` | Live upstream gRPC check against go-service |
| `GET /metrics` | Prometheus exposition |
| `GET /api/v1/greet/{name}` | Calls `go-service.SayHello`, returns JSON |
| `GET /api/v1/info` | Service version + uptime |

---

## GitOps sync order (sync-wave)

```
-3  platform-namespaces
-2  istio-base
-1  istiod
 0  monitoring-stack
+1  go-service · python-service
```

ArgoCD applies waves in order and waits for each wave to be healthy before proceeding.

---

## Infrastructure highlights

| Topic | Approach |
|---|---|
| Auth | GCP Workload Identity — pods authenticate via short-lived STS tokens, no JSON keys |
| Network | Private nodes + Cloud NAT; deny-all-ingress firewall at priority 65534 |
| Node hardening | Shielded VMs (Secure Boot + Integrity Monitoring), COS Containerd |
| mTLS | Istio `PeerAuthentication` STRICT in the `apps` namespace |
| Container | Distroless image, non-root user, `readOnlyRootFilesystem`, `drop: ALL` |
| TF state | GCS with versioning + `public_access_prevention = enforced` |
| IaC checks | tfsec + checkov gate on every PR |
| Image checks | Trivy HIGH/CRITICAL gate before push |

---

## Getting started

### 1. Bootstrap the state bucket (once)

```bash
gcloud storage buckets create gs://cn-fintech-gke-tfstate-dev \
  --location=asia-southeast1 \
  --uniform-bucket-level-access

gcloud storage buckets update gs://cn-fintech-gke-tfstate-dev --versioning
```

### 2. Provision infrastructure

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### 3. Get cluster credentials

```bash
gcloud container clusters get-credentials fintech-gke-dev \
  --region asia-southeast1 \
  --project cn-fintech-gke
```

### 4. Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=120s
```

### 5. Bootstrap

```bash
kubectl apply -f argocd/apps/app-of-apps.yaml
argocd app list
```

### 6. Grafana

```bash
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
```

Open `http://localhost:3000`. Loki, Tempo, and Prometheus are pre-wired as datasources. The two custom dashboards load automatically via the `grafana_dashboard: "1"` ConfigMap label.

---

## Observability

Logs (Loki), metrics (Prometheus), and traces (Tempo) are correlated by `trace_id`. Both services emit structured JSON logs that Promtail parses and labels. The app-latency dashboard shows p50/p95/p99 latency and gRPC error rate side by side.

To follow a request end-to-end: Grafana → Explore → Tempo → pick a trace from go-service → the trace spans python-service → go-service with the gRPC call visible as a child span.

---

## What would be added for real production

- Cloud KMS CMEK for GKE etcd + GCS
- Binary Authorization (signed images only)
- External Secrets Operator → GCP Secret Manager
- Multi-region failover + Global Load Balancer
- Velero cluster backups
- OPA Gatekeeper / Kyverno policy engine
- Istio JWT auth at the gateway (Identity Platform / Auth0)
- SLO burn-rate alerts via Pyrra or Sloth
- Chaos Mesh for resilience testing
- VPC Service Controls perimeter around GCS/GCP APIs
