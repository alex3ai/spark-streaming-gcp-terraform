# ==============================================================================
# VPC NETWORK
# ==============================================================================

resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  project                 = var.project_id

  description = "VPC para Spark Streaming Pipeline"
}

# ==============================================================================
# SUBNET
# ==============================================================================

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.network_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id

  # Habilitar Private Google Access (acesso a APIs sem IP público)
  private_ip_google_access = true

  # Logs de flow (desabilitado para economizar)
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.0  # Desabilitado
    metadata             = "EXCLUDE_ALL_METADATA"
  }
}

# ==============================================================================
# FIREWALL RULES (Mínimo Necessário)
# ==============================================================================

# Regra 1: Permitir SSH interno (troubleshooting)
resource "google_compute_firewall" "allow_internal_ssh" {
  name    = "${var.network_name}-allow-ssh"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.subnet_cidr]
  target_tags   = ["dataproc"]
}

# Regra 2: Permitir comunicação interna do Dataproc
resource "google_compute_firewall" "allow_internal_dataproc" {
  name    = "${var.network_name}-allow-dataproc-internal"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_tags = ["dataproc"]
  target_tags = ["dataproc"]
}

# Regra 3: Permitir acesso à Spark UI (OPCIONAL - remover em produção)
resource "google_compute_firewall" "allow_spark_ui" {
  name    = "${var.network_name}-allow-spark-ui"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["8080", "18080"]  # Spark Master UI, History Server
  }

  # ATENÇÃO: Restringir ao seu IP público em produção
  source_ranges = ["0.0.0.0/0"]  # TEMPORÁRIO
  target_tags   = ["dataproc"]
}