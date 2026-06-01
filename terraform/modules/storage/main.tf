resource "google_storage_bucket" "tf_state" {
  name                        = var.bucket_name
  location                    = var.region
  project                     = var.project_id
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 10
      with_state         = "ARCHIVED"
    }
  }

  # Prevent public access
  public_access_prevention = "enforced"

  labels = var.labels
}

# State locking via GCS native locking (available in TF >= 1.7 with gcs backend)
resource "google_storage_bucket_iam_binding" "tf_state_admin" {
  bucket = google_storage_bucket.tf_state.name
  role   = "roles/storage.objectAdmin"

  members = var.state_admins
}
