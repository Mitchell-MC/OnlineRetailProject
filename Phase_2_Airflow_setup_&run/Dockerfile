# Use the official Apache Airflow image
FROM apache/airflow:2.9.2

# Copy the Python requirements file and install all dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy your project's directories into the Airflow image
COPY dags /opt/airflow/dags
COPY plugins /opt/airflow/plugins
COPY include /opt/airflow/include