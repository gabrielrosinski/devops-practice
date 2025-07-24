# Stage 1
ARG pythonVersion=3.11
FROM python:${pythonVersion}-slim as builder

# Set environment variables
# Prevents .pyc files from being written (they're not needed in containers).
ENV PYTHONDONTWRITEBYTECODE 1
# Ensures logs are output directly without buffering, which is important for real-time log visibility in Docker.
ENV PYTHONUNBUFFERED 1

# Create and set working directory
WORKDIR /app

# Copies the requirements.txt file into the container Needed before installing Python dependencies.
COPY requirements.txt /app/

# Install dependencies
RUN pip install -r requirements.txt


# Stage 2
FROM python:${pythonVersion}-slim AS production

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Copy installed Python dependencies from build stage
COPY --from=builder /usr/local/lib/python3.11/site-packages/ /usr/local/lib/python3.11/site-packages

# Create and set working directory
WORKDIR /app

# Copy application code
COPY . /app/

# Expose port
# Informs Docker that the container listens on port 5000. Default port for Flask.
EXPOSE 5000

# Set Flask environment variables
# Required for Flask to run properly in a Docker container.
ENV FLASK_APP=app.py
ENV FLASK_RUN_HOST=0.0.0.0

# Run the app
#CMD ["flask", "run"]
CMD ["python", "app.py"]