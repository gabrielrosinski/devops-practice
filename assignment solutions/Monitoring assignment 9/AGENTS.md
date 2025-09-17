# Repository Guidelines

## Project Structure & Module Organization
The FastAPI demo lives in `test_app/` with `main.py` and a Dockerfile ready for image builds. Cluster assets sit under `k8s/` (deployments, services, ServiceMonitor) and `prometheus/` (standalone configs and alert rules). Platform scripts are split into `linux/` and `windows/` folders, while `grafana-dashboard*.json` contains the importable dashboards.

## Build, Test, and Development Commands
Use `linux/deploy.sh` (or `windows\deploy.ps1`) from the repo root to provision the entire stack on a local Kubernetes cluster. For quick app-only runs, build and tag the container with `docker build -t kube-mon-demo:test ./test_app` and start it via `docker run -p 8000:8000 kube-mon-demo:test`. During development, run the API with `uvicorn test_app.main:app --reload --port 8000` to exercise endpoints before redeploying.

## Coding Style & Naming Conventions
Python code follows standard FastAPI practices: 4-space indentation, descriptive snake_case names, and module-level metric definitions. Keep HTTP route handlers thin and colocate monitoring helpers beside the app code. Shell and PowerShell scripts mirror existing filenames (`deploy.sh`, `healthcheck.ps1`); use lowercase dashed names for new Bash utilities and PascalCase for PowerShell functions.

## Testing Guidelines
No automated test harness ships today; rely on functional checks. After changes, run `linux/healthcheck.sh --show-commands` (or `windows\healthcheck.ps1 -ShowCommands`) and issue `curl http://localhost:8000/healthz` and `/readyz` to confirm readiness gating still behaves. When introducing new endpoints, add validation steps to the health scripts or document equivalent curl probes in the README.

## Commit & Pull Request Guidelines
Follow the existing history: concise, imperative commit subjects such as `add readiness metrics`. Bundle related script and manifest updates together, and include a brief bullet list in the body when touching multiple platforms. PRs should describe the scenario exercised (e.g., "validated on Minikube + Docker Desktop"), link any issue numbers, and capture screenshots of Grafana dashboards when UI changes are made.

## Security & Configuration Tips
Avoid committing kubeconfig files or credentials; rely on the deploy scripts to surface temporary secrets. Keep alert thresholds in `prometheus/prometheus-alerts.yaml` aligned with app latency changes, and document any newly required environment variables in the README before merging.
