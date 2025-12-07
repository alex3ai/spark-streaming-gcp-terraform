# Abra o arquivo: app/config.py
# Substitua o conteúdo ou edite a seção relevante:

import os

class Config:
    # ... (Mantenha as configurações anteriores de Environment Detection e GCP) ...
    IS_DATAPROC = os.path.exists("/usr/local/share/google/dataproc")
    IS_DOCKER = os.path.exists("/.dockerenv")

    GCP_PROJECT_ID = os.environ.get("GCP_PROJECT_ID", "spark-streaming-gcp-terraform")
    GCS_BUCKET = os.environ.get("GCS_BUCKET", f"{GCP_PROJECT_ID}-data-lake")

    # ==============================================================================
    # STREAMING SOURCE CONTROL (SRE WAR STRATEGY)
    # ==============================================================================
    # 'rate' = Gera dados sintéticos (para teste de infra)
    # 'pubsub' = Tenta conectar no Pub/Sub (requer JARs corretos)
    # 'kafka' = Conecta no Kafka
    STREAM_SOURCE = os.environ.get("STREAM_SOURCE", "rate") 

    # ==============================================================================
    # KAFKA / PUBSUB CONFIG
    # ==============================================================================
    KAFKA_BOOTSTRAP_SERVERS = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092" if IS_DOCKER else "127.0.0.1:9094")
    KAFKA_TOPIC_INPUT = "raw-tweets"
    KAFKA_TOPIC_OUTPUT = "processed-sentiment"

    PUBSUB_SUBSCRIPTION = f"projects/{GCP_PROJECT_ID}/subscriptions/sentiment-sub"

    # ==============================================================================
    # SPARK CONFIG
    # ==============================================================================
    SPARK_APP_NAME = "SentimentAnalysisStream-GCP"
    SPARK_MASTER = "yarn" if IS_DATAPROC else "local[*]"

    # ==============================================================================
    # STORAGE PATHS
    # ==============================================================================
    # Checkpoint único para evitar conflitos
    CHECKPOINT_LOCATION = f"gs://{GCS_BUCKET}/checkpoints/sentiment_job_rate_v1" if IS_DATAPROC else "/data/checkpoints/v1"
    
    # NLTK
    NLTK_DATA_DIR = "/usr/local/share/nltk_data" if IS_DATAPROC else "/opt/spark/nltk_data"
    
    # Tuning
    SPARK_SQL_SHUFFLE_PARTITIONS = "4"

settings = Config()