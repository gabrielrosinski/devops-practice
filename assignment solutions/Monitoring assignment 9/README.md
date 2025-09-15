# Kubernetes Monitoring Assignment 9

This project demonstrates Kubernetes monitoring using Prometheus and Grafana with a FastAPI demo application.

## Prerequisites

- Docker Desktop with Kubernetes enabled OR Minikube
- kubectl CLI tool
- Helm (automatically installed by deploy.sh if missing)

## Quick Start

### 1. Deploy Everything

Run the automated deployment script:

```bash
./deploy.sh
```

**Note**: The scripts are automatically executable when cloned from the Git repository.

This script will:
- Check and install all dependencies (Docker, kubectl, Helm)
- Start minikube if available (or use Docker Desktop Kubernetes)
- Build the demo application Docker image
- Deploy all Kubernetes resources (namespaces, app, services)
- Install Prometheus and Grafana via Helm
- Configure monitoring with ServiceMonitor
- Display access information with credentials

### 2. Access the Services

After deployment completes, use the provided commands to access:

**Prometheus**: Port-forward and open http://localhost:9090
**Grafana**: Port-forward and open http://localhost:3000 (credentials shown in deploy output)
**Demo App**: Port-forward and open http://localhost:8000

### 3. Import Dashboard

**IMPORTANT**: You must manually import the dashboard to see alerts and monitoring data:

1. In Grafana, go to Dashboards → Import
2. Upload the `grafana-dashboard.json` file from this directory
3. The dashboard will show metrics from the demo application including:
   - HTTP request rates and latencies
   - Application alerts & restart monitoring
   - Status code distributions
   - Endpoint usage patterns

### 4. Test the Application

Use the curl commands shown in the deploy script output to test all endpoints:
- `/` - Main endpoint
- `/healthz` - Health check
- `/readyz` - Readiness check
- `/metrics` - Prometheus metrics

## Project Structure

- `test_app/` - FastAPI demo application with Prometheus metrics
- `k8s/` - Kubernetes manifests
  - `namespace.yaml` - Creates app and monitoring namespaces
  - `deployment.yaml` - Demo application deployment
  - `service.yaml` - Service to expose the demo app
  - `servicemonitor.yaml` - ServiceMonitor for Prometheus scraping
- `prometheus/` - Prometheus configurations
  - `prometheus.yml` - Prometheus configuration (for standalone setup)
  - `prometheus-alerts.yaml` - Alert rules for the monitoring stack
- `grafana-dashboard.json` - Pre-configured Grafana dashboard

## Cleanup

Run the automated cleanup script:

```bash
./cleanup.sh
```

This will remove all deployed resources including the demo app, Prometheus stack, namespaces, and Docker images.

## Troubleshooting

1. **ServiceMonitor not working**: Ensure the `release: prometheus-stack` label matches your Helm release name
2. **Metrics not showing**: Check that the demo app pods are running and the service is accessible
3. **Grafana login issues**: Use the dynamic password shown in deploy.sh output
4. **Port conflicts**: Make sure ports 3000, 8000, and 9090 are not in use by other applications
5. **Dependencies missing**: The deploy.sh script will check and install missing dependencies automatically