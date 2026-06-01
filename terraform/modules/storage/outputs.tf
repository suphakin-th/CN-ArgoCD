output "bucket_name" {
  value = google_storage_bucket.tf_state.name
}

output "bucket_url" {
  value = google_storage_bucket.tf_state.url
}
