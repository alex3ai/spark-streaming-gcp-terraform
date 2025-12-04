# ==============================================================================
# CLOUD STORAGE BUCKET (Data Lake)
# ==============================================================================

resource "google_storage_bucket" "data_lake" {
  name          = var.bucket_name
  location      = var.bucket_location
  project       = var.project_id
  storage_class = var.storage_class
  
  # Prevenir destruição acidental (REMOVER em dev)
  force_destroy = var.environment == "dev" ? true : false

  # Versionamento (DESABILITADO para economizar)
  versioning {
    enabled = false
  }

  # Lifecycle rules para otimizar custos
  lifecycle_rule {
    condition {
      age = 30  # Dias
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"  # Mais barato após 30 dias
    }
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"  # Deletar dados antigos
    }
  }

  # Uniform bucket-level access (IAM simplificado)
  uniform_bucket_level_access {
    enabled = true
  }

  labels = var.labels
}

# ==============================================================================
# FOLDERS STRUCTURE (Via objects vazios)
# ==============================================================================

resource "google_storage_bucket_object" "folders" {
  for_each = toset([
    "jobs/",
    "data/raw/",
    "data/processed/",
    "checkpoints/",
    "logs/",
    "scripts/"
  ])

  name    = each.value
  content = " "  # Objeto vazio para criar "pasta"
  bucket  = google_storage_bucket.data_lake.name
}