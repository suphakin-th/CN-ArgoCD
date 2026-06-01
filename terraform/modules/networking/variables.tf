variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "labels" {
  type    = map(string)
  default = {}
}
