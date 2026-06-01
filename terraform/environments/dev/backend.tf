terraform {
  backend "gcs" {
    bucket = "cn-fintech-gke-tfstate-dev"
    prefix = "fintech/dev"
  }
}
