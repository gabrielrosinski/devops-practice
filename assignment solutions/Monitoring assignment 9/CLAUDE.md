# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Kubernetes monitoring demonstration project that showcases a complete observability stack with Prometheus, Grafana, and ArgoCD. The project includes a FastAPI demo application with integrated Prometheus metrics, comprehensive alerting rules, and automated deployment/cleanup scripts.

## Key Commands

### Deployment
**Linux/macOS:**
- `./deploy.sh` - Automated deployment of the entire monitoring stack
- `./cleanup.sh` - Complete cleanup of all deployed resources

**Windows:**
- `.\deploy.ps1` - Enhanced PowerShell deployment with auto-elevation and system validation
- `.\cleanup.ps1` - Comprehensive PowerShell cleanup with minikube reset options
- `.\healthcheck.ps1` - Real-time health monitoring and service discovery
- `.\status.ps1` - Quick deployment status check with credentials

### Windows-Enhanced Scripts Features
- **Auto-elevation**: Automatic administrator privilege request for dependency installation
- **System validation**: Pre-flight checks for CPU (2+ cores), RAM (4GB+), disk space (20GB+)
- **Dependency management**: Auto-installs Docker Desktop, kubectl, Helm, ArgoCD CLI
- **Error recovery**: Handles minikube networking issues and image loading problems
- **Service discovery**: Automatic credential retrieval and URL generation
- **Directory validation**: Ensures scripts run from correct project location

### Manual Access Commands (after deployment)
- Prometheus: `kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090`
- Grafana: `kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80`
- Demo App: `kubectl port-forward -n app svc/kube-mon-demo 8000:80`
- ArgoCD: `kubectl port-forward svc/argocd-server -n argocd 8080:443`

### Windows Service Monitoring
- `.\status.ps1` - Quick status with URLs, credentials, and port-forward commands
- `.\healthcheck.ps1` - Single comprehensive health check
- `.\healthcheck.ps1 -ShowCommands` - Display all access commands and credentials
- `.\healthcheck.ps1 -TestConnectivity` - Test localhost port connectivity
- `.\healthcheck.ps1 -Continuous` - Real-time monitoring dashboard (10s refresh)
- `.\healthcheck.ps1 -Continuous -RefreshSeconds 5` - Custom refresh rate

### Credentials Access
**Manual (Linux/macOS):**
- Grafana admin password: `kubectl get secret --namespace monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode`
- ArgoCD admin password: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

**Automatic (Windows):**
- `.\status.ps1` - Shows all credentials automatically
- `.\healthcheck.ps1 -ShowCommands` - Displays credentials with access commands

## Architecture

### Core Components
- **Demo Application** (`test_app/`): FastAPI service with Prometheus metrics endpoint, health checks, and configurable startup delays
- **Kubernetes Manifests** (`k8s/`): Deployment, service, servicemonitor, and namespace definitions
- **Monitoring Stack**: Prometheus + Grafana via Helm chart (kube-prometheus-stack)
- **GitOps**: ArgoCD for application lifecycle management
- **Alerting**: Comprehensive PrometheusRule definitions for application monitoring

### Key Namespaces
- `app`: Demo application deployment
- `monitoring`: Prometheus, Grafana, and alert manager
- `argocd`: ArgoCD server and components

### Demo Application Features
- Prometheus metrics at `/metrics` endpoint
- Health checks: `/healthz` (liveness), `/readyz` (readiness)
- Configurable startup delays via `READY_DELAY_SECONDS` environment variable
- Request tracking with custom metrics (http_requests_total, http_request_duration_seconds, http_requests_in_progress)

### Alert Rules
The system includes alerts for:
- High CPU usage relative to requests/limits
- High memory usage relative to limits
- Pod restart frequency monitoring
- Application availability (deployment down)
- Crash loop detection

## Important Notes

### Manual Dashboard Import Required
After deployment, the Grafana dashboard must be manually imported:
1. Access Grafana at http://localhost:3000
2. Navigate to Dashboards → Import
3. Upload `grafana-dashboard.json`

### ServiceMonitor Configuration
The ServiceMonitor uses label selector `release: prometheus-stack` to match the Helm release name. This must align with the actual Prometheus operator installation.

### Dependencies
**Linux/macOS (deploy.sh):**
- Docker (must be running)
- kubectl
- Helm
- ArgoCD CLI
- Minikube (optional, falls back to Docker Desktop Kubernetes)

**Windows (deploy.ps1):**
- Docker Desktop with Kubernetes enabled
- kubectl, Helm, ArgoCD CLI (auto-installed via Chocolatey/winget)
- PowerShell 5.1+
- System requirements: 2+ CPU cores, 4GB+ RAM, 20GB+ disk space
- Windows 10/11 with container support (Hyper-V or WSL2)

### Cross-Platform Deployment Patterns

**Standard Deployment Flow:**
1. **Linux/macOS**: `./deploy.sh` → Manual monitoring → `./cleanup.sh`
2. **Windows**: `.\deploy.ps1` → `.\status.ps1` or `.\healthcheck.ps1` → `.\cleanup.ps1`

**Windows-Enhanced Deployment Features:**
- **Pre-deployment validation**: Enforces minimum system requirements (hard stops)
- **Auto-elevation handling**: Prompts for admin privileges when needed for dependency installation
- **Intelligent error recovery**: Handles common Windows issues (minikube networking, image loading)
- **Context switching**: Automatically switches between minikube and Docker Desktop contexts
- **Deployment summarization**: Shows final status with all access information

### Windows-Specific Features
- **System validation**: Pre-flight checks for CPU (2+ cores), RAM (4GB+), disk space (20GB+), Windows version
- **Automatic dependency installation**: Uses Chocolatey or winget to install missing tools
- **Health monitoring**: Real-time dashboard showing service status, pod health, and connectivity
- **Service discovery**: Automatic detection of service endpoints and credentials
- **Connectivity testing**: Port availability checks for localhost access
- **Minikube issue resolution**: Detects and fixes Windows-specific minikube problems
- **Terminal management**: Prevents auto-closing on errors with user-friendly pauses

### Image Management
The demo application uses image `your-dockerhub/kube-mon-demo:0.1` and is built locally during deployment.

**Linux/macOS**: Standard Docker build and minikube image loading
**Windows**: Enhanced error handling for minikube image loading issues, with automatic fallback to Docker Desktop context