output "workload_identity_sa_email" {
  value = google_service_account.workload_identity_sa.email
}

output "argocd_sa_email" {
  value = google_service_account.argocd_sa.email
}

output "monitoring_sa_email" {
  value = google_service_account.monitoring_sa.email
}
