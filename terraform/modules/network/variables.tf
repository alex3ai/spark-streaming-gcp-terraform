variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "network_name" {
  description = "Nome da VPC"
  type        = string
}

variable "region" {
  description = "Região GCP"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR range da subnet"
  type        = string
}