from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator

# Default arguments for the DAG
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Define the DAG
dag = DAG(
    'sample_retail_dag',
    default_args=default_args,
    description='Sample DAG for Online Retail Project - Testing Airflow Setup',
    schedule_interval=timedelta(days=1),
    catchup=False,
    tags=['retail', 'sample', 'test'],
)

def print_welcome():
    """Sample Python function for testing"""
    print("🎉 Welcome to Online Retail Project Airflow!")
    print("✅ Airflow is successfully configured and running!")
    print("📊 This is a sample DAG to verify the installation.")
    return "Airflow setup verification completed successfully!"

def print_environment_info():
    """Print environment information"""
    import os
    import sys
    
    print("🔧 Environment Information:")
    print(f"Python version: {sys.version}")
    print(f"Airflow Home: {os.environ.get('AIRFLOW_HOME', 'Not set')}")
    print(f"Current working directory: {os.getcwd()}")
    
    # Check for important directories
    dag_folder = "/home/ubuntu/OnlineRetailProject/airflow-project/dags"
    logs_folder = "/home/ubuntu/OnlineRetailProject/airflow-project/logs"
    
    print(f"DAGs folder exists: {os.path.exists(dag_folder)}")
    print(f"Logs folder exists: {os.path.exists(logs_folder)}")
    
    return "Environment check completed!"

def simulate_data_processing():
    """Simulate a data processing task"""
    import time
    import random
    
    print("📊 Starting simulated data processing...")
    
    # Simulate processing time
    processing_time = random.uniform(1, 3)
    time.sleep(processing_time)
    
    records_processed = random.randint(100, 1000)
    print(f"✅ Processed {records_processed} retail records in {processing_time:.2f} seconds")
    
    return f"Successfully processed {records_processed} records"

# Task 1: Welcome message
welcome_task = PythonOperator(
    task_id='welcome_message',
    python_callable=print_welcome,
    dag=dag,
)

# Task 2: Environment check
env_check_task = PythonOperator(
    task_id='environment_check',
    python_callable=print_environment_info,
    dag=dag,
)

# Task 3: Bash command test
bash_test_task = BashOperator(
    task_id='bash_test',
    bash_command='echo "🔧 Bash operator test successful!" && date && whoami',
    dag=dag,
)

# Task 4: Simulated data processing
data_processing_task = PythonOperator(
    task_id='simulate_data_processing',
    python_callable=simulate_data_processing,
    dag=dag,
)

# Task 5: Final success message
success_task = BashOperator(
    task_id='success_notification',
    bash_command='echo "🎉 Sample DAG execution completed successfully! Airflow is ready for production use."',
    dag=dag,
)

# Define task dependencies
welcome_task >> env_check_task >> bash_test_task >> data_processing_task >> success_task 