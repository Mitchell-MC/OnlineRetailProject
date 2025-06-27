# producer.py
import csv
import json
import time
from kafka import KafkaProducer

# Configuration
KAFKA_TOPIC = 'user_events'
KAFKA_SERVER = 'localhost:9092'
CSV_FILE_PATH = '2019-Oct.csv' # Make sure this path is correct

# Initialize Kafka Producer
# value_serializer converts Python objects to JSON bytes
producer = KafkaProducer(
    bootstrap_servers=KAFKA_SERVER,
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

print("Starting producer...")
# Open the massive CSV file
with open(CSV_FILE_PATH, mode='r') as csv_file:
    csv_reader = csv.DictReader(csv_file)

    # Read file row-by-row
    for row in csv_reader:
        try:
            # Send the row (as a dictionary) to the Kafka topic
            producer.send(KAFKA_TOPIC, value=row)
            print(f"Sent: {row['event_type']} for user {row['user_id']}")

            # Control the stream speed (e.g., 10 messages per second)
            time.sleep(0.1) 

        except Exception as e:
            print(f"Error sending message: {e}")

# Ensure all messages are sent before exiting
producer.flush()
print("Producer finished.")