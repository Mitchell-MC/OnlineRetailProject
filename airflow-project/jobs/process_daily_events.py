# jobs/process_daily_events.py
import argparse
from pyspark.sql import SparkSession, Window
from pyspark.sql.functions import col, count, sum, max, row_number

def run_job(spark, s3_input_path, snowflake_table):
    """
    Main ETL logic for processing daily e-commerce events.

    :param spark: The SparkSession object.
    :param s3_input_path: Path to the raw Parquet data in S3.
    :param snowflake_table: Fully qualified name of the target Snowflake table.
    """
    # 1. READ (Extract)
    print(f"Reading raw data from: {s3_input_path}")
    raw_df = spark.read.parquet(s3_input_path)

    # 2. TRANSFORM
    print("Transforming data...")
    cleaned_df = raw_df.filter(col("user_id").isNotNull()) \
                       .withColumn("price", col("price").cast("double")) \
                       .na.drop(subset=["user_id", "price"])

    brand_window = Window.partitionBy("user_id").orderBy(col("brand_count").desc())
    favorite_brand_df = cleaned_df \
        .filter((col("event_type") == "purchase") & (col("brand").isNotNull())) \
        .groupBy("user_id", "brand") \
        .agg(count("*").alias("brand_count")) \
        .withColumn("rank", row_number().over(brand_window)) \
        .filter(col("rank") == 1) \
        .select(col("user_id"), col("brand").alias("FAVORITE_BRAND"))

    category_window = Window.partitionBy("user_id").orderBy(col("category_count").desc())
    most_viewed_category_df = cleaned_df \
        .filter((col("event_type") == "view") & (col("category_code").isNotNull())) \
        .groupBy("user_id", "category_code") \
        .agg(count("*").alias("category_count")) \
        .withColumn("rank", row_number().over(category_window)) \
        .filter(col("rank") == 1) \
        .select(col("user_id"), col("category_code").alias("MOST_VIEWED_CATEGORY"))

    purchase_metrics_df = cleaned_df \
        .filter(col("event_type") == "purchase") \
        .groupBy("user_id") \
        .agg(
            count("*").alias("TOTAL_PURCHASES"),
            sum("price").alias("TOTAL_SPEND")
        )

    last_seen_df = cleaned_df.groupBy("user_id").agg(
        max("event_time").alias("LAST_SEEN_DATE")
    )

    customer_360_df = last_seen_df \
        .join(favorite_brand_df, "user_id", "left") \
        .join(most_viewed_category_df, "user_id", "left") \
        .join(purchase_metrics_df, "user_id", "left") \
        .select(
            col("user_id").alias("USER_ID"),
            col("FAVORITE_BRAND"),
            col("MOST_VIEWED_CATEGORY"),
            col("TOTAL_PURCHASES"),
            col("TOTAL_SPEND"),
            col("LAST_SEEN_DATE")
        )

    # 3. LOAD
    print(f"Loading data into Snowflake table: {snowflake_table}")
    customer_360_df.write \
        .format("net.snowflake.spark.snowflake") \
        .option("dbtable", snowflake_table) \
        .mode("overwrite") \
        .save()

    print("ETL job completed successfully.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--s3_input_path", required=True, help="Input path for raw data in S3")
    parser.add_argument("--snowflake_table", required=True, help="Target table in Snowflake")
    args = parser.parse_args()

    spark = SparkSession.builder \
        .appName("EcommerceDailyETL") \
        .getOrCreate()

    run_job(spark, args.s3_input_path, args.snowflake_table)