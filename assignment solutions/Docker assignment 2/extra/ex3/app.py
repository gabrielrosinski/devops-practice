from flask import Flask
import redis
import os

app = Flask(__name__)

# Connect to Redis using environment variables (with fallback)
redis_host = os.getenv("REDIS_HOST", "localhost")
redis_port = int(os.getenv("REDIS_PORT", 6379))
r = redis.Redis(host=redis_host, port=redis_port, decode_responses=True)

@app.route('/')
def home():
    visits = r.incr("counter")
    return f"Hello! This page has been visited {visits} times."

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
