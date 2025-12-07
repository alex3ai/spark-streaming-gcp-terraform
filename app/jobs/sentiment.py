import os
import nltk
from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json, col, pandas_udf, to_json, struct, current_timestamp
from pyspark.sql.types import FloatType
import pandas as pd
from nltk.sentiment import SentimentIntensityAnalyzer

# Import config
from app.config import settings
from app.schemas.tweet import TWEET_SCHEMA

# ==============================================================================
# NLTK SETUP
# ==============================================================================
if settings.NLTK_DATA_DIR:
    nltk.data.path.append(settings.NLTK_DATA_DIR)

try:
    nltk.data.find("sentiment/vader_lexicon.zip")
except LookupError:
    nltk.download("vader_lexicon", quiet=True)

# ==============================================================================
# SENTIMENT ANALYSIS UDF
# ==============================================================================
@pandas_udf(FloatType())
def analyze_sentiment(text_series: pd.Series) -> pd.Series:
    sid = SentimentIntensityAnalyzer()
    def get_score(text):
        try:
            return sid.polarity_scores(str(text))["compound"]
        except Exception:
            return 0.0
    return text_series.apply(get_score)

# ==============================================================================
# MAIN JOB
# ==============================================================================
def main():
    print("=" * 80)
    print(f"🚀 INICIANDO JOB: {settings.SPARK_APP_NAME}")
    print(f"🌊 Output: BigQuery ({settings.GCP_PROJECT_ID}.sentiment_analysis.tweets)")
    print("=" * 80)
    
    spark = (
        SparkSession.builder
        .appName(settings.SPARK_APP_NAME)
        .config("spark.sql.execution.arrow.pyspark.enabled", "true")
        .getOrCreate()
    )
    spark.sparkContext.setLogLevel("WARN")

    # 1. LEITURA (Kafka)
    print(f"📥 Lendo do Kafka: {settings.KAFKA_BOOTSTRAP_SERVERS}")
    df_raw = (
        spark.readStream
        .format("kafka")
        .option("kafka.bootstrap.servers", settings.KAFKA_BOOTSTRAP_SERVERS)
        .option("subscribe", settings.KAFKA_TOPIC_INPUT)
        .option("startingOffsets", "latest")
        .option("failOnDataLoss", "false")
        .load()
    )

    # 2. PROCESSAMENTO
    df_parsed = df_raw.select(
        from_json(col("value").cast("string"), TWEET_SCHEMA).alias("data")
    ).select("data.*")

    df_processed = df_parsed.withColumn(
        "sentiment_score", 
        analyze_sentiment(col("text"))
    )
    
    # Adiciona timestamp de processamento
    df_final = df_processed.withColumn("processed_at", current_timestamp())

    # 3. ESCRITA (BIGQUERY)
    # Define checkpoint único para esta versão BigQuery
    bq_checkpoint = f"{settings.CHECKPOINT_LOCATION}_bq"
    
    print(f"📤 Escrevendo no BigQuery... (Checkpoint: {bq_checkpoint})")
    
    query = (
        df_final.writeStream
        .outputMode("append")
        .format("bigquery")
        .option("table", f"{settings.GCP_PROJECT_ID}.sentiment_analysis.tweets")
        .option("temporaryGcsBucket", settings.GCS_BUCKET)
        .option("checkpointLocation", bq_checkpoint)
        .trigger(processingTime="15 seconds")
        .start()
    )
    
    print("✅ Stream iniciado! Verifique o BigQuery.")
    query.awaitTermination()

if __name__ == "__main__":
    main()