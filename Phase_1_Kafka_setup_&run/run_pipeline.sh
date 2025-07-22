#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Cleanup function to be called on script exit ---
cleanup() {
    echo ""
    echo "--- Shutting down ---"
    # Kill the background producer process
    if kill -0 $PRODUCER_PID 2>/dev/null; then
        echo "Stopping Python producer (PID: $PRODUCER_PID)..."
        kill $PRODUCER_PID
    fi
    # Stop and remove the Docker containers
    echo "Stopping Docker containers..."
    docker-compose down
    echo "Cleanup complete."
}

# --- Trap script exit and interruptions to run the cleanup function ---
trap cleanup EXIT INT TERM

# --- Step 1: Start Docker Containers in Detached Mode ---
echo "--- Starting Kafka container (in detached mode) ---"
docker-compose up -d

# --- Step 2: Wait for Kafka to be Ready ---
echo "--- Waiting for Kafka to be ready (this may take a moment) ---"
until docker-compose exec kafka kafka-topics --bootstrap-server kafka:9092 --list > /dev/null 2>&1; do
  echo "Kafka is not ready yet. Retrying in 5 seconds..."
  sleep 5
done
echo ">>> Kafka is up and running!"

# --- Step 3: Create the Kafka Topic ---
echo "--- Creating Kafka topic: user_events ---"
docker-compose exec kafka kafka-topics --create \
  --topic user_events \
  --bootstrap-server kafka:9092 \
  --partitions 1 \
  --replication-factor 1 \
  --if-not-exists
echo ">>> Topic 'user_events' created successfully."

# --- Step 4: Start the Python Producer in the Background ---
echo "--- Starting Python data producer in the background ---"
# Make sure you have the required library: pip install kafka-python
python producer.py &
PRODUCER_PID=$! # Capture the Process ID of the last background command
echo ">>> Producer started with PID: $PRODUCER_PID. It will run in the background."

# --- Step 5: Run the Spark Streaming Consumer ---
echo "--- Submitting Spark streaming job ---"
echo "This will connect to Kafka and write to your data lake."
echo "Press CTRL+C to stop the Spark job and shut down the pipeline."

# IMPORTANT: Ensure your AWS credentials are set as environment variables
# export AWS_ACCESS_KEY_ID=YOUR_KEY
# export AWS_SECRET_ACCESS_KEY=YOUR_SECRET
#
# Also, ensure you have updated the S3 paths in stream_consumer.py

spark-submit \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0,org.apache.hadoop:hadoop-aws:3.3.4,com.amazonaws:aws-java-sdk-bundle:1.12.262 \
  stream_consumer.py

# The 'trap' will handle cleanup when the Spark job is stopped.