variable "project_id" { type = string }
variable "region" { type = string }
variable "bucket_name" { type = string }
variable "environment" { type = string }
variable "labels" { type = map(string); default = {} }
variable "state_admins" {
  type        = list(string)
  description = "IAM members with objectAdmin on the TF state bucket"
  default     = []
}
