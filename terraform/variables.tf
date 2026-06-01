variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Primary GCP region"
  type        = string
  default     = "asia-southeast1"
}

variable "zone" {
  description = "Primary GCP zone"
  type        = string
  default     = "asia-southeast1-a"
}

variable "environment" {
  description = "Deployment environment (dev | staging | prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "fintech-gke"
}

variable "vpc_name" {
  description = "VPC network name"
  type        = string
  default     = "fintech-vpc"
}

variable "node_machine_type" {
  description = "Machine type for GKE node pools"
  type        = string
  default     = "e2-standard-4"
}

variable "min_node_count" {
  description = "Minimum nodes per zone"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum nodes per zone"
  type        = number
  default     = 5
}

variable "gcs_state_bucket" {
  description = "GCS bucket name for Terraform remote state"
  type        = string
}

variable "labels" {
  description = "Common labels applied to all resources"
  type        = map(string)
  default = {
    managed-by = "terraform"
    team       = "platform"
  }
}
