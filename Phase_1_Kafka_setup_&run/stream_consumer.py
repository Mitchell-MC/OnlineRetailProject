# stream_consumer.py
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, LongType, TimestampType
from pyspark.sql.functions import from_json, col, window

# --- Configuration ---
KAFKA_TOPIC = "user_events"
KAFKA_SERVER = "localhost:9092"
# Replace with your actual S3/ADLS/GCS path
DATA_LAKE_PATH = "s3://kafka-cust-transactions/raw/user_events" 
CHECKPOINT_PATH = "s3://kafka-cust-transactions/checkpoints/user_events"

# --- Initialize Spark Session ---
# The packages option includes the necessary Kafka connector
spark = SparkSession.builder \
    .appName("UserEventStreamConsumer") \
    .config("spark.jars.packages", "org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0") \
    .getOrCreate()

# --- Define Schema for Incoming JSON Data ---
# This enforces structure on your raw data
schema = StructType([
    StructField("event_time", StringType(), True),
    StructField("event_type", StringType(), True),
    StructField("product_id", StringType(), True),
    StructField("category_id", StringType(), True),
    StructField("category_code", StringType(), True),
    StructField("brand", StringType(), True),
    StructField("price", StringType(), True), # Read as string, cast later
    StructField("user_id", StringType(), True),
    StructField("user_session", StringType(), True),
])

# --- Read from Kafka Source ---
kafka_df = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", KAFKA_SERVER) \
    .option("subscribe", KAFKA_TOPIC) \
    .option("startingOffsets", "latest") \
    .load()

# --- Transform the Data ---
# Kafka messages are key-value pairs. The 'value' column contains our JSON data.
# 1. Cast the binary 'value' to a string.
# 2. Parse the JSON string using the defined schema.
# 3. Select the fields out of the parsed struct.
# 4. Perform type casting and simple validation.
transformed_df = kafka_df.select(from_json(col("value").cast("string"), schema).alias("data")) \
                         .select("data.*") \
                         .withColumn("price", col("price").cast(DoubleType())) \
                         .withColumn("event_timestamp", col("event_time").cast(TimestampType())) \
                         .filter(col("user_id").isNotNull()) # Simple validation

# --- Write Stream to Data Lake ---
# This is where the magic happens.
query = transformed_df.writeStream \
    .format("parquet") \
    .outputMode("append") \
    .partitionBy("event_type") \
    .option("path", DATA_LAKE_PATH) \
    .option("checkpointLocation", CHECKPOINT_PATH) \
    .trigger(processingTime='1 minute') \
    .start()

# Wait for the stream to terminate (e.g., by manual intervention)
query.awaitTermination()