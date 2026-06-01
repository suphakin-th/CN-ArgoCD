module "platform" {
  source = "../../"

  project_id        = var.project_id
  region            = "asia-southeast1"
  zone              = "asia-southeast1-a"
  environment       = "prod"
  cluster_name      = "fintech-gke"
  vpc_name          = "fintech-vpc"
  node_machine_type = "e2-standard-4"
  min_node_count    = 2
  max_node_count    = 10
  gcs_state_bucket  = "${var.project_id}-tfstate-prod"

  labels = {
    managed-by  = "terraform"
    environment = "prod"
    team        = "platform"
    criticality = "high"
  }
}

variable "project_id" {
  type = string
}
