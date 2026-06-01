# GCP service account used by workloads via Workload Identity
resource "google_service_account" "workload_identity_sa" {
  account_id   = "wi-${var.environment}-workload"
  display_name = "Workload Identity SA - ${var.environment}"
  project      = var.project_id
}

# Allow the Kubernetes SA to impersonate the GCP SA (Workload Identity binding)
resource "google_service_account_iam_member" "wi_binding" {
  service_account_id = google_service_account.workload_identity_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[apps/workload-identity-sa]"
}

# Grant GCS read access to the workload SA (for reading app configs from GCS)
resource "google_project_iam_member" "wi_gcs_reader" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.workload_identity_sa.email}"
}

# ArgoCD service account for GKE cluster access
resource "google_service_account" "argocd_sa" {
  account_id   = "argocd-${var.environment}"
  display_name = "ArgoCD Service Account - ${var.environment}"
  project      = var.project_id
}

resource "google_service_account_iam_member" "argocd_wi_binding" {
  service_account_id = google_service_account.argocd_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[argocd/argocd-server]"
}

# Prometheus / monitoring SA
resource "google_service_account" "monitoring_sa" {
  account_id   = "monitoring-${var.environment}"
  display_name = "Prometheus / Monitoring SA - ${var.environment}"
  project      = var.project_id
}

resource "google_project_iam_member" "monitoring_metric_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.monitoring_sa.email}"
}

resource "google_service_account_iam_member" "monitoring_wi_binding" {
  service_account_id = google_service_account.monitoring_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[monitoring/prometheus-sa]"
}
