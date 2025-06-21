from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, sum, max, mode

# Define constants
S3_INPUT_PATH = "s3a://kafka-cust-transactions/raw/user_events/"
SNOWFLAKE_TABLE = "ECOMMERCE_DB.ANALYTICS.CUSTOMER_360_PROFILE"

def main():
    # Initialize Spark session
    spark = SparkSession.builder \
        .appName("EcommerceETL") \
        .config("spark.jars", "/opt/airflow/jobs/spark-snowflake_2.12-2.11.2-spark_3.3.jar") \
        .getOrCreate()
    
    # 1. READ (Extract)
    print(f"Reading raw data from S3 path: {S3_INPUT_PATH}")
    raw_df = spark.read.parquet(S3_INPUT_PATH)

    # 2. TRANSFORM
    print("Transforming data to create Customer 360 profiles...")
    
    # Basic Cleaning
    cleaned_df = raw_df.filter(col("user_id").isNotNull()) \
                       .filter(col("brand").isNotNull()) \
                       .withColumn("price", col("price").cast("double")) \
                       .na.drop(subset=["user_id", "brand", "price"])

    # Feature Engineering: Create user-level aggregates
    views_df = cleaned_df.filter(col("event_type") == "view")
    purchases_df = cleaned_df.filter(col("event_type") == "purchase")

    # Aggregate favorite brand from purchases
    favorite_brand_df = purchases_df.groupBy("user_id").agg(
        mode("brand").alias("FAVORITE_BRAND")
    )

    # Aggregate most viewed category from views
    most_viewed_category_df = views_df.groupBy("user_id").agg(
        mode("category_code").alias("MOST_VIEWED_CATEGORY")
    )

    # Aggregate purchase metrics
    purchase_metrics_df = purchases_df.groupBy("user_id").agg(
        count("*").alias("TOTAL_PURCHASES"),
        sum("price").alias("TOTAL_SPEND")
    )

    # Aggregate last seen date from all events
    last_seen_df = cleaned_df.groupBy("user_id").agg(
        max("event_timestamp").alias("LAST_SEEN_DATE")
    )

    # Join all aggregates together to build the final profile
    customer_360_df = last_seen_df \
        .join(favorite_brand_df, "user_id", "left") \
        .join(most_viewed_category_df, "user_id", "left") \
        .join(purchase_metrics_df, "user_id", "left") \
        .select("USER_ID", "FAVORITE_BRAND", "MOST_VIEWED_CATEGORY", "TOTAL_PURCHASES", "TOTAL_SPEND", "LAST_SEEN_DATE")

    # 3. LOAD
    print(f"Loading data into Snowflake table: {SNOWFLAKE_TABLE}...")
    
    customer_360_df.write \
        .format("net.snowflake.spark.snowflake") \
        .option("dbtable", SNOWFLAKE_TABLE) \
        .mode("overwrite") \
        .save()

    print("ETL job completed successfully.")
    spark.stop()

if __name__ == "__main__":
    main() 