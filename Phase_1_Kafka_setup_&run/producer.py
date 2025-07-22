import csv
import json
import time
import signal
import sys
from kafka import KafkaProducer

# --- Configuration ---
KAFKA_TOPIC = 'user_events'
KAFKA_SERVER = 'localhost:9092'
CSV_FILE_PATH = r'C:\Users\mccal\Downloads\OnlineRetailProject\CSVDump\2019-Oct.csv'


producer = KafkaProducer(
    bootstrap_servers=KAFKA_SERVER,
    value_serializer=lambda v: json.dumps(v).encode('utf-8'),
    batch_size=262122,  
    linger_ms=25,       
    acks='all'          

)
shutdown_requested = False

# --- Signal Handler Function ---
def signal_handler(signum, frame):
    global shutdown_requested
    print(f"\nSignal {signum} received. Initiating graceful shutdown...")
    shutdown_requested = True


signal.signal(signal.SIGINT, signal_handler)

print("Starting producer...")

try:
    
    with open(CSV_FILE_PATH, mode='r') as csv_file:
        csv_reader = csv.DictReader(csv_file)

        for i, row in enumerate(csv_reader):
            if shutdown_requested:
                print("Shutdown requested. Stopping message production.")
                break 

            try:
                
                future = producer.send(KAFKA_TOPIC, value=row)
                
                
                if i % 100 == 0: 
                    print(f"Queued record {i}: {row.get('event_type', 'N/A')} for user {row.get('user_id', 'N/A')}")

                
                

            except Exception as e:
                print(f"Error sending message: {e}")

finally:
    
    print("Flushing any remaining messages...")
    try:
        producer.flush(timeout=30) 
        print("Producer flushed successfully.")
    except Exception as e:
        print(f"Error during producer flush: {e}")

    
    producer.close()
    print("Producer closed.")
    print("Producer finished.")