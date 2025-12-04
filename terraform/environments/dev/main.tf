terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # IMPORTANTE: Comentado por enquanto (state local)
  # Para produção, usar GCS backend
  # backend "gcs" {
  #   bucket = "terraform-state-spark-streaming"
  #   prefix = "dev"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Data sources para informações do projeto
data "google_project" "project" {
  project_id = var.project_id
}

data "google_compute_zones" "available" {
  region = var.region
}