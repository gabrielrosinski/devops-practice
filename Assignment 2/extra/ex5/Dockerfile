# Use a specific version of Python
ARG pythonVersion=3.11
FROM python:${pythonVersion}-slim

WORKDIR /app

# Copy the requirements file and install dependencies
COPY requirements.txt /app/requirements.txt

RUN pip install --no-cache-dir -r /app/requirements.txt

# Copy the rest of the application code
COPY . /app

# Expose ports
EXPOSE 5000

# Environment variables for Flask
ENV FLASK_APP=app.py
ENV FLASK_RUN_HOST=0.0.0.0

# Create a directory for logs and set permissions
RUN mkdir -p /var/log/flask-data \
    && chown -R 10000:10000 /var/log/flask-data


# Command to run the Flask application
CMD ["flask", "run"]