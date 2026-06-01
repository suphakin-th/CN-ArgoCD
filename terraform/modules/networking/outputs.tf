output "vpc_self_link" {
  value = google_compute_network.vpc.self_link
}

output "vpc_name" {
  value = google_compute_network.vpc.name
}

output "subnet_self_link" {
  value = google_compute_subnetwork.primary.self_link
}

output "subnet_name" {
  value = google_compute_subnetwork.primary.name
}

output "pods_range_name" {
  value = "pods"
}

output "services_range_name" {
  value = "services"
}

output "nat_ip" {
  value = google_compute_address.nat.address
}
