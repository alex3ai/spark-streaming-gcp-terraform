# ==============================================================================
# DATAPROC CLUSTER (Cost-Optimized Configuration)
# ==============================================================================

resource "google_dataproc_cluster" "spark_cluster" {
  name    = var.cluster_name
  region  = var.region
  project = var.project_id

  labels = var.labels

  # ==============================================================================
  # CLUSTER CONFIG
  # ==============================================================================
  cluster_config {
    
    # Staging bucket (auto-criado pelo Dataproc)
    staging_bucket = var.staging_bucket_name

    # CRITICAL: Configuração para custo mínimo
    # Single-node cluster: Master faz papel de Master + Worker
    
    # --- MASTER NODE ---
    master_config {
      num_instances = 1
      machine_type  = var.master_machine_type
      
      disk_config {
        boot_disk_type    = "pd-standard"  # HDD mais barato
        boot_disk_size_gb = var.master_boot_disk_size_gb
      }
    }

    # --- WORKER NODES (0 = Single-node mode) ---
    worker_config {
      num_instances = var.num_workers
      machine_type  = var.worker_machine_type
      
      disk_config {
        boot_disk_type    = "pd-standard"
        boot_disk_size_gb = var.worker_boot_disk_size_gb
      }
    }

    # --- PREEMPTIBLE WORKERS (Opcional - 80% desconto) ---
    preemptible_worker_config {
      num_instances = var.num_preemptible_workers
    }

    # ==============================================================================
    # NETWORK CONFIGURATION
    # ==============================================================================
    gce_cluster_config {

      # Sem IP externo (economia + segurança)
      # ATENÇÃO: Exige Private Google Access habilitado na subnet
      internal_ip_only = false

      tags = ["dataproc"]
    }

    # ==============================================================================
    # INITIALIZATION ACTIONS (Bootstrap Script)
    # ==============================================================================
    initialization_action {
      script      = "gs://${var.staging_bucket_name}/scripts/bootstrap.sh"
      timeout_sec = 900  # 15 minutos (margem de segurança SRE)
    } // <-- CHAVE CORRIGIDA

    # ==============================================================================
    # SOFTWARE CONFIGURATION
    # ==============================================================================
    software_config {
  image_version = var.dataproc_image_version
  
  # CRITICAL: Remover HIVE dos componentes opcionais
  optional_components = []  # Vazio = sem Jupyter, sem Hive extra
  
  override_properties = {
    # Desabilita Hive explicitamente
    # "dataproc:dataproc.components.activate" = "SPARK,HDFS,YARN,MAPREDUCE,GCS_CONNECTOR"
    
    # Força Spark a NÃO usar Hive Metastore
    # "spark:spark.sql.catalogImplementation" = "in-memory"  # Usa catálogo em memória
    # "spark:spark.sql.hive.metastore.version" = ""  # String vazia desabilita
    
    # Configurações Spark (manter as existentes)
    "spark:spark.executor.memory"           = "1g"
    "spark:spark.driver.memory"             = "1g"
    "spark:spark.executor.cores"            = "2"
    "spark:spark.sql.shuffle.partitions"    = "4"
    
    # YARN (manter)
    "yarn:yarn.nodemanager.resource.memory-mb" = "12288"  # Mais RAM disponível sem Hive
    "yarn:yarn.scheduler.maximum-allocation-mb" = "12288"
  }
}

    # ==============================================================================
    # LIFECYCLE CONFIGURATION (Auto-delete)
    # ==============================================================================
    lifecycle_config {
      # CRÍTICO: Cluster temporário (desliga automaticamente após idle)
      idle_delete_ttl = var.idle_delete_ttl  # Ex: "3600s" = 1 hora
    }

    # ==============================================================================
    # ENCRYPTION (Opcional - usar chaves gerenciadas)
    # ==============================================================================
    encryption_config {
      kms_key_name = var.kms_key_name  # Deixar vazio para usar chave do Google
    }

    # ==============================================================================
    # ENDPOINT CONFIG (Acesso à UI do Spark)
    # ==============================================================================
    endpoint_config {
      enable_http_port_access = var.enable_component_gateway
    }
  }

  # ==============================================================================
  # TIMEOUTS
  # ==============================================================================
  timeouts {
    create = "30m"
    update = "20m"
    delete = "10m"
  }
}

# ==============================================================================
# IAM POLICY (Service Account Permissions)
# ==============================================================================

resource "google_project_iam_member" "dataproc_worker" {
  project = var.project_id
  role    = "roles/dataproc.worker"
  member  = "serviceAccount:${google_service_account.dataproc_sa.email}"
}

resource "google_service_account" "dataproc_sa" {
  account_id   = "${var.cluster_name}-sa"
  display_name = "Dataproc Cluster Service Account"
  project      = var.project_id
}

# Permissões adicionais para acesso ao GCS
resource "google_project_iam_member" "storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.dataproc_sa.email}"
}

resource "google_project_iam_member" "logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.dataproc_sa.email}"
}