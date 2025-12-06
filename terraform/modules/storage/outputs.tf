output "bucket_name" {
  description = "Nome do bucket criado"
  value       = google_storage_bucket.data_lake.name
}

output "bucket_url" {
  description = "URL do bucket"
  value       = google_storage_bucket.data_lake.url
}

output "bucket_self_link" {
  description = "Self-link do bucket"
  value       = google_storage_bucket.data_lake.self_link
}