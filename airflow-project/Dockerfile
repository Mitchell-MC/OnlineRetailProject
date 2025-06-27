# 1. Start with the Astro Runtime image, which is a best practice for running Airflow with the Astro CLI. 
# Pinning the version ensures a stable and predictable environment. [cite: 81, 82]
FROM quay.io/astronomer/astro-runtime:10.0.0

# 2. Copy the OS-level dependency file. [cite: 83]
# The commented-out lines below show the best practice for installing these packages
# by temporarily switching to the root user.
COPY packages.txt .
# USER root
# RUN apt-get update && xargs -a packages.txt apt-get install -y && apt-get clean
# USER astro

# 3. Copy the Python requirements file and install all dependencies. [cite: 85]
# This step ensures that all necessary Python packages, including providers and the Astro SDK, are available.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. Copy your project's directories into the Astro Runtime image.
# The Astro project structure separates DAGs, plugins, and include files for better organization.
COPY dags /usr/local/airflow/dags
COPY plugins /usr/local/airflow/plugins
COPY include /usr/local/airflow/include