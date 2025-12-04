import nltk
from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json, col, pandas_udf
from pyspark.sql.types import FloatType
import pandas as pd
from nltk.sentiment import SentimentIntensityAnalyzer
from app.config import settings  # noqa: E402
from app.schemas.tweet import TWEET_SCHEMA  # noqa: E402

# --- NLTK FAILSAFE ---
try:
    nltk.data.find("sentiment/vader_lexicon.zip")
except LookupError:
    nltk.download("vader_lexicon", quiet=True)


# --- LÓGICA VETORIZADA (Pandas UDF) ---
@pandas_udf(FloatType())
def analyze_sentiment(text_series: pd.Series) -> pd.Series:
    sid = SentimentIntensityAnalyzer()

    def get_score(text):
        try:
            return sid.polarity_scores(str(text))["compound"]
        except Exception:
            return 0.0

    return text_series.apply(get_score)


def main():
    spark = (
        SparkSession.builder.appName(settings.SPARK_APP_NAME)
        .config("spark.sql.execution.arrow.pyspark.enabled", "true")
        .getOrCreate()
    )

    spark.sparkContext.setLogLevel("WARN")

    # 1. Leitura
    df_raw = (
        spark.readStream.format("kafka")
        .option("kafka.bootstrap.servers", settings.KAFKA_BOOTSTRAP_SERVERS)
        .option("subscribe", settings.KAFKA_TOPIC_INPUT)
        .option("startingOffsets", "latest")
        .load()
    )

    # 2. Parsing
    df_parsed = df_raw.select(from_json(col("value").cast("string"), TWEET_SCHEMA).alias("data")).select("data.*")

    # 3. Processamento
    df_processed = df_parsed.withColumn("sentiment_score", analyze_sentiment(col("text")))

    # 4. Saída
    df_kafka_output = df_processed.selectExpr(
        "CAST(id AS STRING) AS key",
        "to_json(struct(*)) AS value",
    )

    query = (
        df_kafka_output.writeStream.outputMode("append")
        .format("kafka")
        .option("kafka.bootstrap.servers", settings.KAFKA_BOOTSTRAP_SERVERS)
        .option("topic", settings.KAFKA_TOPIC_OUTPUT)
        .option("checkpointLocation", "/data/checkpoints/sentiment_job_v1")
        .start()
    )

    query.awaitTermination()


if __name__ == "__main__":
    main()
