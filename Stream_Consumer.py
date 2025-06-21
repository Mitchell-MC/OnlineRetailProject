# stream_consumer.py
import os
import sys
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, LongType, TimestampType
from pyspark.sql.functions import from_json, col, window

# --- Configuration ---
KAFKA_TOPIC = "user_events"
KAFKA_SERVER = "localhost:9092"

# AWS S3 Configuration
S3_BUCKET = "kafka-cust-transactions"  
S3_REGION = "us-east-1"  
DATA_LAKE_PATH = f"s3a://{S3_BUCKET}/raw/user_events" 
CHECKPOINT_PATH = f"s3a://{S3_BUCKET}/checkpoints/user_events"

def create_spark_session():
    """Create a Spark session with proper configuration for local development and S3"""
    try:
        
        os.environ['HADOOP_HOME'] = 'C:\\Spark\\spark-3.5.4-bin-hadoop3'
        os.environ['SPARK_HOME'] = 'C:\\Spark\\spark-3.5.4-bin-hadoop3'
        
        spark = SparkSession.builder \
            .appName("UserEventStreamConsumer") \
            .config("spark.sql.streaming.checkpointLocation", CHECKPOINT_PATH) \
            .config("spark.sql.adaptive.enabled", "true") \
            .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
            .config("spark.sql.adaptive.skewJoin.enabled", "true") \
            .config("spark.sql.streaming.schemaInference", "true") \
            .config("spark.sql.streaming.forceDeleteTempCheckpointLocation", "true") \
            .config("spark.driver.host", "localhost") \
            .config("spark.driver.bindAddress", "localhost") \
            .config("spark.jars.packages", "org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0,org.apache.hadoop:hadoop-aws:3.3.4,com.amazonaws:aws-java-sdk-bundle:1.12.261") \
            .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
            .config("spark.hadoop.fs.s3a.aws.credentials.provider", "com.amazonaws.auth.DefaultAWSCredentialsProviderChain") \
            .config("spark.hadoop.fs.s3a.endpoint", f"s3.{S3_REGION}.amazonaws.com") \
            .config("spark.hadoop.fs.s3a.path.style.access", "false") \
            .config("spark.hadoop.fs.s3a.block.size", "134217728") \
            .config("spark.hadoop.fs.s3a.buffer.dir", "/tmp") \
            .config("spark.hadoop.fs.s3a.connection.maximum", "1000") \
            .config("spark.hadoop.fs.s3a.connection.timeout", "200000") \
            .config("spark.hadoop.fs.s3a.connection.ttl", "600000") \
            .config("spark.hadoop.fs.s3a.threads.max", "20") \
            .master("local[*]") \
            .getOrCreate()
        
        # Set log level to reduce verbosity
        spark.sparkContext.setLogLevel("WARN")
        return spark
    except Exception as e:
        print(f"Error creating Spark session: {e}")
        print("Trying alternative configuration...")
        
        # Alternative configuration without some problematic settings
        spark = SparkSession.builder \
            .appName("UserEventStreamConsumer") \
            .config("spark.jars.packages", "org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0,org.apache.hadoop:hadoop-aws:3.3.4,com.amazonaws:aws-java-sdk-bundle:1.12.261") \
            .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
            .config("spark.hadoop.fs.s3a.aws.credentials.provider", "com.amazonaws.auth.DefaultAWSCredentialsProviderChain") \
            .config("spark.hadoop.fs.s3a.endpoint", f"s3.{S3_REGION}.amazonaws.com") \
            .master("local[*]") \
            .getOrCreate()
        
        spark.sparkContext.setLogLevel("WARN")
        return spark

# --- Initialize Spark Session ---
print("Initializing Spark session...")
spark = create_spark_session()
print("Spark session created successfully!")

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

print("Setting up Kafka stream...")

# --- Read from Kafka Source ---
try:
    kafka_df = spark.readStream \
        .format("kafka") \
        .option("kafka.bootstrap.servers", KAFKA_SERVER) \
        .option("subscribe", KAFKA_TOPIC) \
        .option("startingOffsets", "latest") \
        .load()

    
    transformed_df = kafka_df.select(from_json(col("value").cast("string"), schema).alias("data")) \
                             .select("data.*") \
                             .withColumn("price", col("price").cast(DoubleType())) \
                             .withColumn("event_timestamp", col("event_time").cast(TimestampType())) \
                             .filter(col("user_id").isNotNull()) # Simple validation

    # --- Write Stream to S3 Data Lake ---
    # This is where the magic happens.
    query = transformed_df.writeStream \
        .format("parquet") \
        .outputMode("append") \
        .partitionBy("event_type") \
        .option("path", DATA_LAKE_PATH) \
        .option("checkpointLocation", CHECKPOINT_PATH) \
        .trigger(processingTime='1 minute') \
        .start()

    print("Stream processing started. Waiting for data...")
    print(f"Data will be written to: {DATA_LAKE_PATH}")
    print(f"Checkpoints will be stored at: {CHECKPOINT_PATH}")

    # Wait for the stream to terminate (e.g., by manual intervention)
    query.awaitTermination()

except Exception as e:
    print(f"Error in stream processing: {e}")
    print("Make sure Kafka is running and accessible at localhost:9092")
    print("You may need to start Kafka first or check your Kafka configuration")
    print("Also ensure your AWS credentials are properly configured")
    sys.exit(1)