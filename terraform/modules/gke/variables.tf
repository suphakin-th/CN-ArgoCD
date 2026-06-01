variable "project_id" { type = string }
variable "region" { type = string }
variable "cluster_name" { type = string }
variable "network" { type = string }
variable "subnetwork" { type = string }
variable "pods_range_name" { type = string }
variable "services_range_name" { type = string }
variable "node_machine_type" { type = string }
variable "min_node_count" { type = number }
variable "max_node_count" { type = number }
variable "environment" { type = string }
variable "labels" { type = map(string); default = {} }
