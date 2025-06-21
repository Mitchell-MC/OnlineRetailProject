# Inherit from the official Airflow image
#
FROM apache/airflow:latest

# Set environment variables for Spark and Hadoop
ENV SPARK_VERSION=3.5.0
ENV HADOOP_VERSION=3
ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$SPARK_HOME/bin
ENV SPARK_DIST_CLASSPATH="$SPARK_HOME/jars/*"

# Switch to root user to install dependencies
USER root

# Install system dependencies, including Java for Spark
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    openjdk-17-jre-headless \
    curl \
    gnupg && \
    apt-get clean && \
    rm -r /var/lib/apt/lists/*

# Download and install Spark
RUN curl -o /tmp/spark.tgz https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz && \
    tar -xf /tmp/spark.tgz -C /opt && \
    mv /opt/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} $SPARK_HOME && \
    rm /tmp/spark.tgz

# Add AWS and Hadoop jars for Spark S3 access
ENV AWS_SDK_VERSION=1.12.367
ENV AWS_HADOOP_VERSION=3.3.2

RUN curl -o $SPARK_HOME/jars/hadoop-aws-${AWS_HADOOP_VERSION}.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${AWS_HADOOP_VERSION}/hadoop-aws-${AWS_HADOOP_VERSION}.jar && \
    curl -o $SPARK_HOME/jars/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_VERSION}/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar

# Switch back to the airflow user before installing python packages
USER airflow

# Install python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt