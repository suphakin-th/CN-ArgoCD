provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

module "networking" {
  source = "./modules/networking"

  project_id   = var.project_id
  region       = var.region
  vpc_name     = var.vpc_name
  environment  = var.environment
  labels       = merge(var.labels, { environment = var.environment })
}

module "gke" {
  source = "./modules/gke"

  project_id        = var.project_id
  region            = var.region
  cluster_name      = "${var.cluster_name}-${var.environment}"
  network           = module.networking.vpc_self_link
  subnetwork        = module.networking.subnet_self_link
  pods_range_name   = module.networking.pods_range_name
  services_range_name = module.networking.services_range_name
  node_machine_type = var.node_machine_type
  min_node_count    = var.min_node_count
  max_node_count    = var.max_node_count
  environment       = var.environment
  labels            = merge(var.labels, { environment = var.environment })

  depends_on = [module.networking]
}

module "iam" {
  source = "./modules/iam"

  project_id   = var.project_id
  cluster_name = module.gke.cluster_name
  environment  = var.environment

  depends_on = [module.gke]
}

module "storage" {
  source = "./modules/storage"

  project_id  = var.project_id
  region      = var.region
  bucket_name = var.gcs_state_bucket
  environment = var.environment
  labels      = merge(var.labels, { environment = var.environment })
}
