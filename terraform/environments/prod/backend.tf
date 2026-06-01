terraform {
  backend "gcs" {
    bucket = "cn-fintech-gke-tfstate-prod"
    prefix = "fintech/prod"
  }
}
