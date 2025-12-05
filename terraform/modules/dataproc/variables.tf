# (Manter as variáveis existentes e adicionar estas se faltarem)

variable "bucket_location" {
  description = "Localização do bucket GCS"
  type        = string
  default     = "US"
}

variable "dataproc_image_version" {
  description = "Versão da imagem Dataproc"
  type        = string
  default     = "2.1-debian11"
}