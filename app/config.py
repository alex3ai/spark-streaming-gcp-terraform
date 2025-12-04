import os


class Config:
    # Kafka Topics
    KAFKA_TOPIC_INPUT = "raw-tweets"
    KAFKA_TOPIC_OUTPUT = "processed-sentiment"

    # --- Lógica SRE: Detecção de Ambiente ---
    # Verifica a existência do arquivo .dockerenv (padrão em containers Linux)
    IS_DOCKER = os.path.exists("/.dockerenv")

    # Decisão de Roteamento:
    # 1. Se IS_DOCKER=True (Spark Container) -> Usa rede interna 'kafka:9092'
    # 2. Se IS_DOCKER=False (Windows/Local)  -> Usa IP direto '127.0.0.1:9094' (Evita timeout IPv6)
    KAFKA_BOOTSTRAP_SERVERS = "kafka:9092" if IS_DOCKER else "127.0.0.1:9094"

    # Spark Configuration
    SPARK_APP_NAME = "SentimentAnalysisStream"
    # Aponta para o master definido no docker-compose
    SPARK_MASTER = "spark://spark-master:7077"

    # NLTK Data Path (Garantindo que o Worker ache os dados baixados no build)
    NLTK_DATA_DIR = "/opt/spark/nltk_data"


settings = Config()
