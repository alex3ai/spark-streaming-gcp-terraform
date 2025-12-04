from pyspark.sql.types import StructType, StructField, StringType, DoubleType

# Schema rígido para garantir performance
TWEET_SCHEMA = StructType(
    [
        StructField("id", StringType(), False),
        StructField("user", StringType(), True),
        StructField("text", StringType(), True),
        StructField("platform", StringType(), True),
        StructField("timestamp", DoubleType(), True),
    ]
)
