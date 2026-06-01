module "platform" {
  source = "../../"

  project_id        = var.project_id
  region            = "asia-southeast1"
  zone              = "asia-southeast1-a"
  environment       = "dev"
  cluster_name      = "fintech-gke"
  vpc_name          = "fintech-vpc"
  node_machine_type = "e2-standard-2"
  min_node_count    = 1
  max_node_count    = 3
  gcs_state_bucket  = "${var.project_id}-tfstate-dev"

  labels = {
    managed-by  = "terraform"
    environment = "dev"
    team        = "platform"
  }
}

variable "project_id" {
  type = string
}
