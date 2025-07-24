# Start from puckel's Airflow image
FROM puckel/docker-airflow:1.10.9

# Switch to root to install extra dependencies (optional)
# USER root

WORKDIR /app

COPY . /app

# Change back to airflow user
USER airflow

# Set environment variables if needed
# ENV AIRFLOW__CORE__EXECUTOR=LocalExecutor

# Expose port
EXPOSE 5000