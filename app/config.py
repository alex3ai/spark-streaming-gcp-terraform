import os


class Config:
    # ==============================================================================
    # ENVIRONMENT DETECTION
    # ==============================================================================
    
    # Detectar se está rodando no Dataproc
    IS_DATAPROC = os.path.exists("/usr/local/share/google/dataproc")
    IS_DOCKER = os.path.exists("/.dockerenv")
    
    # ==============================================================================
    # GCP CONFIGURATION
    # ==============================================================================
    
    # Project ID (ler de metadata service no Dataproc)
    GCP_PROJECT_ID = os.environ.get(
        "GCP_PROJECT_ID",
        "spark-streaming-dev"  # Default para desenvolvimento local
    )
    
    # Cloud Storage
    GCS_BUCKET = os.environ.get(
        "GCS_BUCKET",
        f"{GCP_PROJECT_ID}-data-lake"
    )
    
    # ==============================================================================
    # KAFKA/PUB-SUB CONFIGURATION
    # ==============================================================================
    
    # OPÇÃO 1: Kafka (para manter compatibilidade com projeto local)
    KAFKA_BOOTSTRAP_SERVERS = os.environ.get(
        "KAFKA_BOOTSTRAP_SERVERS",
        "kafka:9092" if IS_DOCKER else "127.0.0.1:9094"
    )
    
    KAFKA_TOPIC_INPUT = "raw-tweets"
    KAFKA_TOPIC_OUTPUT = "processed-sentiment"
    
    # OPÇÃO 2: Google Pub/Sub (para produção na nuvem)
    PUBSUB_TOPIC_INPUT = f"projects/{GCP_PROJECT_ID}/topics/raw-tweets"
    PUBSUB_TOPIC_OUTPUT = f"projects/{GCP_PROJECT_ID}/topics/processed-sentiment"
    PUBSUB_SUBSCRIPTION = f"projects/{GCP_PROJECT_ID}/subscriptions/sentiment-processor"
    
    # Selecionar backend baseado no ambiente
    USE_PUBSUB = IS_DATAPROC
    
    # ==============================================================================
    # SPARK CONFIGURATION
    # ==============================================================================
    
    SPARK_APP_NAME = "SentimentAnalysisStream-GCP"
    
    # Master URL (local para Dataproc, já que roda standalone)
    if IS_DATAPROC:
        SPARK_MASTER = "yarn"  # Dataproc usa YARN por padrão
    elif IS_DOCKER:
        SPARK_MASTER = "spark://spark-master:7077"
    else:
        SPARK_MASTER = "local[*]"
    
    # ==============================================================================
    # STORAGE PATHS (GCS)
    # ==============================================================================
    
    # Checkpoints
    CHECKPOINT_LOCATION = (
        f"gs://{GCS_BUCKET}/checkpoints/sentiment_job_v1"
        if IS_DATAPROC
        else "/data/checkpoints/sentiment_job_v1"
    )
    
    # Data paths
    DATA_RAW_PATH = f"gs://{GCS_BUCKET}/data/raw"
    DATA_PROCESSED_PATH = f"gs://{GCS_BUCKET}/data/processed"
    
    # ==============================================================================
    # NLTK CONFIGURATION
    # ==============================================================================
    
    if IS_DATAPROC:
        NLTK_DATA_DIR = "/usr/local/share/nltk_data"
    else:
        NLTK_DATA_DIR = "/opt/spark/nltk_data"
    
    # ==============================================================================
    # SPARK TUNING (Dataproc-specific)
    # ==============================================================================
    
    if IS_DATAPROC:
        SPARK_EXECUTOR_MEMORY = "1g"
        SPARK_DRIVER_MEMORY = "1g"
        SPARK_EXECUTOR_CORES = "1"
        SPARK_SQL_SHUFFLE_PARTITIONS = "4"


settings = Config()