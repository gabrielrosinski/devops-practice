from fastapi import FastAPI, Request
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import time, os

app = FastAPI(title="kube-mon-demo")

# Prometheus metrics
REQS = Counter("http_requests_total", "Total HTTP requests", ["path", "method", "code"])
LATENCY = Histogram("http_request_duration_seconds", "Request latency", ["path"])
INPROG = Gauge("http_requests_in_progress", "Requests in progress")

BOOT_TIME = time.time()
READY_DELAY = float(os.getenv("READY_DELAY_SECONDS", "0"))  # simulate slow readiness
STARTUP_DELAY = float(os.getenv("STARTUP_DELAY_SECONDS", "0"))  # simulate slow startup

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    path = request.url.path
    method = request.method
    start = time.time()
    INPROG.inc()
    try:
        response = await call_next(request)
        code = response.status_code
        return response
    finally:
        INPROG.dec()
        LATENCY.labels(path=path).observe(time.time() - start)
        REQS.labels(path=path, method=method, code=str(locals().get("code", 500))).inc()

@app.get("/")
def root():
    return {"app": "kube-mon-demo", "status": "ok"}

@app.get("/healthz")
def healthz():
    # Liveness: always OK unless you want to simulate crash conditions
    return {"live": True}

@app.get("/readyz")
def readyz():
    # Readiness: only ready after READY_DELAY seconds since boot
    ready = (time.time() - BOOT_TIME) >= READY_DELAY
    return {"ready": ready}

@app.get("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}
