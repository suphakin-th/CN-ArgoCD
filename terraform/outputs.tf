output "cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.cluster_name
}

output "cluster_endpoint" {
  description = "GKE cluster API endpoint (private)"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = module.gke.cluster_ca_certificate
  sensitive   = true
}

output "vpc_name" {
  description = "VPC network name"
  value       = module.networking.vpc_name
}

output "subnet_name" {
  description = "Primary subnet name"
  value       = module.networking.subnet_name
}

output "workload_identity_sa_email" {
  description = "Kubernetes service account email for Workload Identity"
  value       = module.iam.workload_identity_sa_email
}

output "nat_ip" {
  description = "Static NAT IP for egress traffic"
  value       = module.networking.nat_ip
}
