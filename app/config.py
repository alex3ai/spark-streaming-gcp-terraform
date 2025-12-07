import os
import socket

class Config:
    # ==============================================================================
    # 1. ENVIRONMENT DETECTION
    # ==============================================================================
    IS_DATAPROC = os.path.exists("/usr/local/share/google/dataproc")
    IS_DOCKER = os.path.exists("/.dockerenv")
    
    # ==============================================================================
    # 2. GCP CONFIGURATION
    # ==============================================================================
    GCP_PROJECT_ID = os.environ.get("GCP_PROJECT_ID", "spark-streaming-gcp-terraform")
    GCS_BUCKET = os.environ.get("GCS_BUCKET", f"{GCP_PROJECT_ID}-data-lake")
    
    # ==============================================================================
    # 3. KAFKA CONFIGURATION (AUTO-DISCOVERY)
    # ==============================================================================
    
    # Lógica inteligente para definir o Broker correto
    if IS_DATAPROC:
        # Se estamos no Dataproc, o Kafka está instalado no Master Node
        # O padrão de nome é: [nome-do-cluster]-m
        # Vamos tentar pegar o hostname ou forçar o padrão
        try:
            hostname = socket.gethostname()
            if "-w-" in hostname: # Se cair num worker, aponta pro master
                DEFAULT_KAFKA = hostname.split("-w-")[0] + "-m:9092"
            elif "-m" in hostname: # Se já estiver no master
                DEFAULT_KAFKA = f"{hostname}:9092"
            else:
                DEFAULT_KAFKA = "spark-sentiment-dev-m:9092" # Fallback seguro
        except:
            DEFAULT_KAFKA = "spark-sentiment-dev-m:9092"
            
        print(f"🔧 CONFIG: Ambiente Dataproc detectado. Kafka Broker: {DEFAULT_KAFKA}")
        
    elif IS_DOCKER:
        DEFAULT_KAFKA = "kafka:9092"
    else:
        DEFAULT_KAFKA = "127.0.0.1:9094"

    # Prioridade: Variável de Ambiente > Auto-Discovery > Local
    KAFKA_BOOTSTRAP_SERVERS = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", DEFAULT_KAFKA)
    
    KAFKA_TOPIC_INPUT = "raw-tweets"
    KAFKA_TOPIC_OUTPUT = "processed-sentiment"
    
    # ==============================================================================
    # 4. SPARK CONFIGURATION
    # ==============================================================================
    SPARK_APP_NAME = "SentimentAnalysisStream-GCP"
    
    if IS_DATAPROC:
        SPARK_MASTER = "yarn"
    elif IS_DOCKER:
        SPARK_MASTER = "spark://spark-master:7077"
    else:
        SPARK_MASTER = "local[*]"
    
    # ==============================================================================
    # 5. STORAGE & PATHS
    # ==============================================================================
    CHECKPOINT_LOCATION = (
        f"gs://{GCS_BUCKET}/checkpoints/sentiment_job_v1"
        if IS_DATAPROC
        else "/data/checkpoints/sentiment_job_v1"
    )
    
    # Stream Source Control
    STREAM_SOURCE = os.environ.get("STREAM_SOURCE", "kafka")
    
    # ==============================================================================
    # 6. NLTK & TUNING
    # ==============================================================================
    if IS_DATAPROC:
        NLTK_DATA_DIR = "/usr/local/share/nltk_data"
        SPARK_EXECUTOR_MEMORY = "1g"
        SPARK_DRIVER_MEMORY = "1g"
        SPARK_EXECUTOR_CORES = "1"
        SPARK_SQL_SHUFFLE_PARTITIONS = "4"
    else:
        NLTK_DATA_DIR = "/opt/spark/nltk_data"

settings = Config()