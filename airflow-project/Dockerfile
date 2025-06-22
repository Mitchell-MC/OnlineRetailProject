# Start from the official Apache Airflow image
FROM apache/airflow:2.9.2

# Copy the requirements file into the image
COPY requirements.txt /

# Install the python packages specified in requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt

# Set the user to airflow to avoid permission issues
USER airflow