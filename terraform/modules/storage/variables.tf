variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "bucket_name" {
  description = "Nome único do bucket"
  type        = string
}

variable "bucket_location" {
  description = "Localização do bucket"
  type        = string
  default     = "US"
}

variable "storage_class" {
  description = "Classe de storage"
  type        = string
  default     = "STANDARD"
}

variable "environment" {
  description = "Ambiente (dev/prod)"
  type        = string
}

variable "labels" {
  description = "Labels para o bucket"
  type        = map(string)
  default     = {}
}