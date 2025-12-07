# Abra o arquivo: app/jobs/sentiment.py
# Substitua o conteúdo por este código ajustado:

import os
import nltk
import json
import time
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, pandas_udf, from_json, to_json, struct, expr, concat, lit
from pyspark.sql.types import FloatType, StringType
import pandas as pd
from nltk.sentiment import SentimentIntensityAnalyzer

# Import config
from app.config import settings
from app.schemas.tweet import TWEET_SCHEMA

# --- NLTK SETUP ---
if settings.NLTK_DATA_DIR:
    nltk.data.path.append(settings.NLTK_DATA_DIR)

try:
    nltk.data.find("sentiment/vader_lexicon.zip")
except LookupError:
    nltk.download("vader_lexicon", quiet=True)

# --- PANDAS UDF ---
@pandas_udf(FloatType())
def analyze_sentiment(text_series: pd.Series) -> pd.Series:
    sid = SentimentIntensityAnalyzer()
    def get_score(text):
        try:
            return sid.polarity_scores(str(text))["compound"]
        except:
            return 0.0
    return text_series.apply(get_score)

def main():
    print("=" * 80)
    print(f"🚀 INICIANDO JOB: {settings.SPARK_APP_NAME}")
    print(f"🌍 Ambiente: {'Dataproc' if settings.IS_DATAPROC else 'Local'}")
    print(f"🌊 Fonte: {settings.STREAM_SOURCE}")
    print(f"💾 Checkpoint: {settings.CHECKPOINT_LOCATION}")
    print("=" * 80)
    
    spark = SparkSession.builder \
        .appName(settings.SPARK_APP_NAME) \
        .config("spark.sql.shuffle.partitions", settings.SPARK_SQL_SHUFFLE_PARTITIONS) \
        .getOrCreate()

    spark.sparkContext.setLogLevel("WARN")

    # ==============================================================================
    # 1. LEITURA DO STREAM
    # ==============================================================================
    
    if settings.STREAM_SOURCE == "rate":
        print("🧪 MODO SIMULAÇÃO (Rate Source): Gerando dados sintéticos...")
        
        # Gera 2 linhas por segundo
        df_stream = spark.readStream \
            .format("rate") \
            .option("rowsPerSecond", 2) \
            .load()
        
        # Simula o JSON que viria do Kafka/PubSub
        # Cria um JSON string na coluna 'value'
        df_raw = df_stream.withColumn("value", 
            concat(
                lit('{"id":"'), col("timestamp").cast("string"), 
                lit('", "user":"simulated_user", "platform":"test", "text":"I love Spark Streaming on Dataproc! It is amazing and fast. timestamp: '), 
                col("timestamp").cast("string"), 
                lit('"}')
            )
        )
        
    elif settings.STREAM_SOURCE == "pubsub":
        print(f"☁️ Lendo do Pub/Sub Lite: {settings.PUBSUB_SUBSCRIPTION}")
        df_stream = spark.readStream \
            .format("pubsublite") \
            .option("pubsublite.subscription", settings.PUBSUB_SUBSCRIPTION) \
            .load()
        df_raw = df_stream.withColumn("value", col("data").cast("string"))
        
    else: # Kafka
        print(f"🏠 Lendo do Kafka: {settings.KAFKA_BOOTSTRAP_SERVERS}")
        df_stream = spark.readStream \
            .format("kafka") \
            .option("kafka.bootstrap.servers", settings.KAFKA_BOOTSTRAP_SERVERS) \
            .option("subscribe", settings.KAFKA_TOPIC_INPUT) \
            .load()
        df_raw = df_stream.selectExpr("CAST(value AS STRING)")

    # ==============================================================================
    # 2. PARSING & PROCESSAMENTO
    # ==============================================================================
    
    print("🔍 Parseando e Processando...")
    
    # Parse JSON
    df_parsed = df_raw.select(from_json(col("value"), TWEET_SCHEMA).alias("data")).select("data.*")
    
    # Aplica Sentiment Analysis
    df_processed = df_parsed.withColumn("sentiment_score", analyze_sentiment(col("text")))
    
    # Adiciona timestamp de processamento
    df_final = df_processed.withColumn("processed_at", expr("current_timestamp()"))

    # ==============================================================================
    # 3. SAÍDA (CONSOLE / LOGS)
    # ==============================================================================
    
    # Para validar a infra, vamos escrever no Console do Dataproc (Driver logs)
    # Em produção, você mudaria para BigQuery ou GCS
    
    print("📤 Iniciando escrita (Console Sink)...")
    
    query = df_final.writeStream \
        .outputMode("append") \
        .format("console") \
        .option("truncate", "false") \
        .option("checkpointLocation", settings.CHECKPOINT_LOCATION) \
        .trigger(processingTime="15 seconds") \
        .start()
    
    print("✅ Stream iniciado! Verifique os logs do driver.")
    query.awaitTermination()

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"❌ Erro fatal: {e}")
        raise