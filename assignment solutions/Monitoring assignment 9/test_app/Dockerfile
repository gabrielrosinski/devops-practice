FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
EXPOSE 8000
ENV READY_DELAY_SECONDS=5
ENV STARTUP_DELAY_SECONDS=0
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
