terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

data "google_project" "project" {
  project_id = var.project_id
}

# ==============================================================================
# MODULE: NETWORK
# ==============================================================================

module "network" {
  source = "../../modules/network"

  project_id   = var.project_id
  network_name = var.network_name
  region       = var.region
  subnet_cidr  = var.subnet_cidr
}

# ==============================================================================
# MODULE: STORAGE
# ==============================================================================

module "storage" {
  source = "../../modules/storage"

  project_id      = var.project_id
  bucket_name     = var.bucket_name
  bucket_location = var.bucket_location
  storage_class   = var.storage_class
  environment     = var.environment
  labels          = var.labels
}

# ==============================================================================
# MODULE: DATAPROC
# ==============================================================================

module "dataproc" {
  source = "../../modules/dataproc"

  # Dependências explícitas (aguarda criação da rede e storage)
  depends_on = [
    module.network,
    module.storage
  ]

  project_id    = var.project_id
  region        = var.region
  cluster_name  = var.cluster_name

  # Network configuration
  network_self_link = module.network.network_self_link
  subnet_self_link  = module.network.subnet_self_link

  # Compute configuration
  master_machine_type      = var.master_machine_type
  worker_machine_type      = var.worker_machine_type
  num_workers              = var.num_workers
  num_preemptible_workers  = var.num_preemptible_workers
  master_boot_disk_size_gb = var.master_boot_disk_size_gb
  worker_boot_disk_size_gb = var.worker_boot_disk_size_gb

  # Software configuration
  dataproc_image_version = "2.1-debian11"
  staging_bucket_name    = module.storage.bucket_name

  # Lifecycle (AUTO-DELETE após 1 hora de idle)
  idle_delete_ttl = "3600s"

  # Security (SA do Compute Engine Padrão)
  service_account_email = "${var.project_id}-compute@developer.gserviceaccount.com"
  enable_component_gateway = true

  labels = var.labels
}