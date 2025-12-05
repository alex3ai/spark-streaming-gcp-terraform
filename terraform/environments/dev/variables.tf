# ==============================================================================
# PROJECT VARIABLES
# ==============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region (us-central1 para Free Tier)"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "dataproc_image_version" {
  description = "Versão da imagem Dataproc (2.0-debian11 é mais estável para single-node)"
  type        = string
  default     = "2.1-debian11"  # Spark 3.3.2 + Hive Metastore estável
}

# ==============================================================================
# NETWORK VARIABLES
# ==============================================================================

variable "network_name" {
  description = "Nome da VPC"
  type        = string
  default     = "spark-streaming-vpc"
}

variable "subnet_cidr" {
  description = "CIDR range para subnet"
  type        = string
  default     = "10.0.0.0/24"
}

# ==============================================================================
# DATAPROC VARIABLES (Cost Optimized)
# ==============================================================================

variable "cluster_name" {
  description = "Nome do cluster Dataproc"
  type        = string
  default     = "spark-sentiment-cluster"
}

variable "master_machine_type" {
  description = "Tipo de máquina do master (e2-medium = Free Tier limite)"
  type        = string
  default     = "e2-medium"  # 2 vCPU, 4GB RAM
}

variable "worker_machine_type" {
  description = "Tipo de máquina dos workers"
  type        = string
  default     = "e2-medium"
}

variable "num_workers" {
  description = "Número de workers (0 = single-node)"
  type        = number
  default     = 0  # CUSTO ZERO: Single-node cluster
}

variable "num_preemptible_workers" {
  description = "Número de workers preemptíveis (80% desconto)"
  type        = number
  default     = 0
}

variable "master_boot_disk_size_gb" {
  description = "Tamanho do disco do master em GB"
  type        = number
  default     = 30  # Mínimo permitido
}

variable "worker_boot_disk_size_gb" {
  description = "Tamanho do disco dos workers em GB"
  type        = number
  default     = 30
}

# ==============================================================================
# STORAGE VARIABLES
# ==============================================================================

variable "bucket_name" {
  description = "Nome do bucket GCS (deve ser globalmente único)"
  type        = string
}

variable "storage_class" {
  description = "Classe de storage (STANDARD, NEARLINE)"
  type        = string
  default     = "STANDARD"  # Free Tier: 5GB
}

variable "bucket_location" {
  description = "Localização do bucket (US = multi-region)"
  type        = string
  default     = "US"
}

# ==============================================================================
# SPARK JOB VARIABLES
# ==============================================================================

variable "spark_job_main_file" {
  description = "Arquivo principal do job Spark"
  type        = string
  default     = "gs://BUCKET_NAME/jobs/sentiment.py"
}

variable "spark_job_args" {
  description = "Argumentos para o job Spark"
  type        = list(string)
  default     = []
}

# ==============================================================================
# TAGS E LABELS
# ==============================================================================

variable "labels" {
  description = "Labels para recursos GCP"
  type        = map(string)
  default = {
    project     = "spark-streaming"
    environment = "dev"
    managed_by  = "terraform"
    cost_center = "data-engineering"
  }
}