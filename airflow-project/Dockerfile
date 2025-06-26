# Start from the official Apache Airflow image
FROM apache/airflow:2.9.2

# Install Java (required for Spark)
USER root
RUN apt-get update && \
    apt-get install -y openjdk-17-jdk-headless && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME environment variable
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin

# Copy the requirements file into the image
COPY requirements.txt /

# Install the python packages specified in requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt

# Set the user to airflow to avoid permission issues
USER airflow