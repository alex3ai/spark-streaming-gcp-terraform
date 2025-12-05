# (Arquivo já criado na Parte 1 - verificar se todas as referências estão corretas)

# Exemplo de output adicional útil:
output "dataproc_service_account" {
  description = "Service Account do Dataproc"
  value       = module.dataproc.service_account_email
  sensitive   = true
}

output "spark_ui_access" {
  description = "Como acessar a Spark UI"
  value       = module.dataproc.spark_ui_url
}