# ==============================================================================
# PROJECT OUTPUTS
# ==============================================================================

output "project_id" {
  description = "ID do projeto GCP"
  value       = var.project_id
}

output "region" {
  description = "Região GCP"
  value       = var.region
}

# ==============================================================================
# NETWORK OUTPUTS
# ==============================================================================

output "network_name" {
  description = "Nome da VPC criada"
  value       = module.network.network_name
}

output "network_self_link" {
  description = "Self-link da VPC"
  value       = module.network.network_self_link
}

output "subnet_name" {
  description = "Nome da subnet criada"
  value       = module.network.subnet_name
}

# ==============================================================================
# STORAGE OUTPUTS
# ==============================================================================

output "bucket_name" {
  description = "Nome do bucket GCS"
  value       = module.storage.bucket_name
}

output "bucket_url" {
  description = "URL do bucket GCS"
  value       = module.storage.bucket_url
}

# ==============================================================================
# DATAPROC OUTPUTS
# ==============================================================================

output "cluster_name" {
  description = "Nome do cluster Dataproc"
  value       = module.dataproc.cluster_name
}

output "master_instance_name" {
  description = "Nome da instância master"
  value       = module.dataproc.master_instance_name
}

output "cluster_bucket" {
  description = "Bucket staging do cluster"
  value       = module.dataproc.cluster_bucket
}

# ==============================================================================
# CUSTOS ESTIMADOS (Informacional)
# ==============================================================================

output "estimated_monthly_cost_usd" {
  description = "Custo estimado mensal (baseado em uso 24/7)"
  value = "ATENÇÃO: e2-medium 24/7 = ~$25/mês. Use cluster ephemeral!"
}