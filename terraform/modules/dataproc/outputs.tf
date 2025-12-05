output "cluster_name" {
  description = "Nome do cluster Dataproc"
  value       = google_dataproc_cluster.spark_cluster.name
}

output "cluster_id" {
  description = "ID do cluster"
  value       = google_dataproc_cluster.spark_cluster.id
}

output "master_instance_name" {
  description = "Nome da instância master"
  value       = google_dataproc_cluster.spark_cluster.cluster_config[0].master_config[0].instance_names[0]
}

output "cluster_bucket" {
  description = "Bucket de staging do cluster"
  value       = google_dataproc_cluster.spark_cluster.cluster_config[0].staging_bucket
}

output "service_account_email" {
  description = "Email da Service Account do cluster"
  # Referencia o recurso Service Account que é criado dentro deste módulo
  value       = google_service_account.dataproc_sa.email
}

output "spark_ui_url" {
  description = "URL da Spark UI (via Component Gateway)"
  value       = "https://console.cloud.google.com/dataproc/clusters/${google_dataproc_cluster.spark_cluster.name}/monitoring?project=${var.project_id}"
}