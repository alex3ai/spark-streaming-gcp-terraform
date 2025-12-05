# ==============================================================================
# PROJECT VARIABLES
# ==============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "cluster_name" {
  description = "Nome do cluster Dataproc"
  type        = string
}

variable "kms_key_name" {
  description = "Nome da chave KMS para encryption (opcional)"
  type        = string
  default     = ""
}

# ==============================================================================
# NETWORK VARIABLES
# ==============================================================================

variable "network_self_link" {
  description = "Self-link da VPC"
  type        = string
}

variable "subnet_self_link" {
  description = "Self-link da subnet"
  type        = string
}

# ==============================================================================
# COMPUTE VARIABLES
# ==============================================================================

variable "master_machine_type" {
  description = "Tipo de máquina do master"
  type        = string
  default     = "e2-medium"
}

variable "worker_machine_type" {
  description = "Tipo de máquina dos workers"
  type        = string
  default     = "e2-medium"
}

variable "num_workers" {
  description = "Número de workers (0 = single-node)"
  type        = number
  default     = 0
}

variable "num_preemptible_workers" {
  description = "Número de workers preemptíveis"
  type        = number
  default     = 0
}

variable "master_boot_disk_size_gb" {
  description = "Tamanho do disco do master"
  type        = number
  default     = 30
}

variable "worker_boot_disk_size_gb" {
  description = "Tamanho do disco dos workers"
  type        = number
  default     = 30
}

# ==============================================================================
# SOFTWARE & STAGING VARIABLES
# ==============================================================================

variable "dataproc_image_version" {
  description = "Versão da imagem Dataproc"
  type        = string
  default     = "2.0-debian11" // <-- NOVO VALOR
}

variable "staging_bucket_name" {
  description = "Nome do bucket para staging"
  type        = string
}

# ==============================================================================
# LIFECYCLE VARIABLES
# ==============================================================================

variable "idle_delete_ttl" {
  description = "Tempo de idle antes de auto-delete (ex: 3600s)"
  type        = string
  default     = "3600s"
}

# ==============================================================================
# SECURITY VARIABLES
# ==============================================================================

# **ATENÇÃO: Este é o argumento faltante 'service_account_email' (Se estiver usando SA externa)**
variable "service_account_email" {
  description = "Email da Service Account para o cluster Dataproc"
  type        = string
  default     = "" # Pode ser vazio se a SA padrão for usada implicitamente, mas é melhor declarar
}

variable "enable_component_gateway" {
  description = "Habilitar acesso HTTP às UIs (Spark, YARN)"
  type        = bool
  default     = true
}

# ==============================================================================
# LABELS
# ==============================================================================

variable "labels" {
  description = "Labels para o cluster"
  type        = map(string)
  default     = {}
}