import os
import nltk
from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json, col, pandas_udf
from pyspark.sql.types import FloatType
import pandas as pd
from nltk.sentiment import SentimentIntensityAnalyzer

# Import config
from app.config import settings
from app.schemas.tweet import TWEET_SCHEMA

# ==============================================================================
# NLTK SETUP (com fallback)
# ==============================================================================

# Configurar NLTK data path
if settings.NLTK_DATA_DIR:
    nltk.data.path.append(settings.NLTK_DATA_DIR)

try:
    nltk.data.find("sentiment/vader_lexicon.zip")
except LookupError:
    print("⚠️ VADER lexicon não encontrado. Baixando...")
    nltk.download("vader_lexicon", quiet=True)


# ==============================================================================
# PANDAS UDF (Vectorized Sentiment Analysis)
# ==============================================================================

@pandas_udf(FloatType())
def analyze_sentiment(text_series: pd.Series) -> pd.Series:
    """
    Análise de sentimento vetorizada usando NLTK VADER.
    
    Args:
        text_series: Série Pandas com textos para análise
        
    Returns:
        Série com scores de sentimento (-1.0 a +1.0)
    """
    sid = SentimentIntensityAnalyzer()

    def get_score(text):
        try:
            return sid.polarity_scores(str(text))["compound"]
        except Exception as e:
            print(f"Erro ao processar texto: {e}")
            return 0.0

    return text_series.apply(get_score)


# ==============================================================================
# MAIN SPARK JOB
# ==============================================================================

def main():
    """
    Job principal de Spark Streaming para análise de sentimento.
    
    Fluxo:
    1. Lê stream do Kafka/Pub-Sub
    2. Parseia JSON
    3. Aplica análise de sentimento
    4. Escreve resultado no tópico de saída
    """
    
    print("=" * 80)
    print(f"INICIANDO JOB: {settings.SPARK_APP_NAME}")
    print(f"Ambiente: {'Dataproc' if settings.IS_DATAPROC else 'Local'}")
    print(f"Master: {settings.SPARK_MASTER}")
    print(f"Checkpoint: {settings.CHECKPOINT_LOCATION}")
    print("=" * 80)
    
    # Criar SparkSession
    spark = (
        SparkSession.builder
        .appName(settings.SPARK_APP_NAME)
        .config("spark.sql.execution.arrow.pyspark.enabled", "true")
        .config("spark.sql.shuffle.partitions", settings.SPARK_SQL_SHUFFLE_PARTITIONS)
        .getOrCreate()
    )

    spark.sparkContext.setLogLevel("WARN")

    # ==============================================================================
    # 1. LEITURA DO STREAM (Kafka)
    # ==============================================================================
    
    print("📥 Iniciando leitura do stream...")
    
    df_raw = (
        spark.readStream
        .format("kafka")
        .option("kafka.bootstrap.servers", settings.KAFKA_BOOTSTRAP_SERVERS)
        .option("subscribe", settings.KAFKA_TOPIC_INPUT)
        .option("startingOffsets", "latest")
        .option("failOnDataLoss", "false")  # Importante para ambientes cloud
        .load()
    )


    # ==============================================================================
    # 2. PARSING DO JSON
    # ==============================================================================
    
    print("🔍 Parseando mensagens JSON...")
    
    df_parsed = (
        df_raw
        .select(from_json(col("value").cast("string"), TWEET_SCHEMA).alias("data"))
        .select("data.*")
    )

    # ==============================================================================
    # 3. APLICAÇÃO DA ANÁLISE DE SENTIMENTO
    # ==============================================================================
    
    print("🧠 Aplicando análise de sentimento (Pandas UDF)...")
    
    df_processed = df_parsed.withColumn(
        "sentiment_score", 
        analyze_sentiment(col("text"))
    )
    
    # Adicionar timestamp de processamento
    from pyspark.sql.functions import current_timestamp
    df_processed = df_processed.withColumn("processed_at", current_timestamp())

    # ==============================================================================
    # 4. PREPARAÇÃO PARA SAÍDA (Kafka Format)
    # ==============================================================================
    
    df_kafka_output = df_processed.selectExpr(
        "CAST(id AS STRING) AS key",
        "to_json(struct(*)) AS value",
    )

    # ==============================================================================
    # 5. ESCRITA NO STREAM DE SAÍDA
    # ==============================================================================
    
    print(f"📤 Configurando escrita para: {settings.KAFKA_TOPIC_OUTPUT}")
    
    query = (
        df_kafka_output.writeStream
        .outputMode("append")
        .format("kafka")
        .option("kafka.bootstrap.servers", settings.KAFKA_BOOTSTRAP_SERVERS)
        .option("topic", settings.KAFKA_TOPIC_OUTPUT)
        .option("checkpointLocation", settings.CHECKPOINT_LOCATION)
        .trigger(processingTime="10 seconds")  # Micro-batch a cada 10s
        .start()
    )
    
    print("✅ Stream iniciado com sucesso!")
    print(f"📊 Checkpoint location: {settings.CHECKPOINT_LOCATION}")
    print("⏳ Aguardando dados... (Ctrl+C para parar)")
    
    # Aguardar término (manual ou por erro)
    query.awaitTermination()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n🛑 Job interrompido pelo usuário")
    except Exception as e:
        print(f"\n❌ Erro durante execução do job: {e}")
        raise