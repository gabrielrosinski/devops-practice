# Kubernetes Monitoring Assignment 9

This project demonstrates Kubernetes monitoring using Prometheus and Grafana with a FastAPI demo application.

## Prerequisites

### Linux/macOS
- Docker Desktop with Kubernetes enabled OR Minikube
- kubectl CLI tool
- Helm (automatically installed by deploy.sh if missing)

### Windows
- Docker Desktop with Kubernetes enabled OR Minikube
- kubectl CLI tool
- Helm (automatically installed by deploy.ps1 if missing)
- PowerShell 5.1 or higher
- Windows 10/11 with container support
- Minimum: 2 CPU cores, 4GB RAM, 20GB free disk space
- Recommended: 4+ CPU cores, 8GB+ RAM

## Quick Start

### 1. Deploy Everything

**Linux/macOS:**
```bash
./deploy.sh
```

**Windows:**
```powershell
.\deploy.ps1
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
**ArgoCD**: Port-forward and open https://localhost:8080 (credentials shown in deploy output)

**Windows users**: Use `.\healthcheck.ps1 -ShowCommands` to get all access commands and credentials.

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
- `deploy.ps1` - Windows PowerShell deployment script with system requirements validation
- `cleanup.ps1` - Windows PowerShell cleanup script
- `healthcheck.ps1` - Windows real-time health monitoring and service discovery
- `status.ps1` - Quick deployment status check with access credentials

## Cross-Platform Support

This project now supports both **Linux/macOS** and **Windows** environments with equivalent functionality.

### Linux/macOS Scripts
- `./deploy.sh` - Bash deployment script
- `./cleanup.sh` - Bash cleanup script
- Manual monitoring via kubectl commands

### Windows PowerShell Scripts
- `.\deploy.ps1` - Full deployment with auto-elevation and system validation
- `.\cleanup.ps1` - Comprehensive cleanup with minikube reset options
- `.\healthcheck.ps1` - Real-time monitoring dashboard
- `.\status.ps1` - Quick status check with credentials

## Service Status and Monitoring

### Quick Status Check (Windows)
Get deployment status, service URLs, and credentials:

```powershell
.\status.ps1
```

Shows:
- Component deployment status (replicas ready)
- Service access URLs and port-forward commands
- Usernames and passwords for Grafana and ArgoCD
- Quick launch commands for all services

### Advanced Health Monitoring (Windows)
Real-time monitoring with detailed connectivity tests:

```powershell
.\healthcheck.ps1                     # Single comprehensive health check
.\healthcheck.ps1 -ShowCommands       # Display all access commands and credentials
.\healthcheck.ps1 -TestConnectivity   # Test localhost port connectivity
.\healthcheck.ps1 -Continuous         # Continuous monitoring (10s refresh)
.\healthcheck.ps1 -Continuous -RefreshSeconds 5  # Custom refresh rate
```

### Linux/macOS Monitoring
Monitor service health manually using kubectl commands or the provided deployment script output.

## Cleanup

**Linux/macOS:**
```bash
./cleanup.sh
```

**Windows:**
```powershell
.\cleanup.ps1
```

This will remove all deployed resources including the demo app, Prometheus stack, namespaces, and Docker images.

## Troubleshooting

### General Issues
1. **ServiceMonitor not working**: Ensure the `release: prometheus-stack` label matches your Helm release name
2. **Metrics not showing**: Check that the demo app pods are running and the service is accessible
3. **Grafana login issues**: Use the dynamic password shown in deploy script output
4. **Port conflicts**: Make sure ports 3000, 8000, 8080, and 9090 are not in use by other applications
5. **Dependencies missing**: The deploy scripts will check and install missing dependencies automatically

### Windows-Specific Features
The Windows PowerShell scripts include enhanced features not available in the Linux version:

1. **Automatic system validation**: Pre-flight checks for CPU, RAM, disk space, and Windows version
2. **Auto-elevation**: Automatic administrator privilege request for dependency installation
3. **Smart dependency management**: Auto-installs Docker Desktop, kubectl, Helm via Chocolatey/winget
4. **Enhanced error handling**: Graceful degradation and recovery for common Windows issues
5. **Real-time monitoring**: Live service health dashboard with connectivity testing
6. **Service discovery**: Automatic credential retrieval and access URL generation
7. **Minikube issue resolution**: Automatic detection and fixing of Windows minikube networking problems

### Windows-Specific Issues
1. **PowerShell execution policy**: Run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` if scripts are blocked
2. **WSL2 backend**: If Hyper-V is not available, Docker Desktop will use WSL2 backend automatically
3. **Chocolatey installation**: The script will install Chocolatey if package managers are missing
4. **System requirements**: Use `.\deploy.ps1` to check if your system meets minimum requirements
5. **Service discovery**: Use `.\status.ps1` or `.\healthcheck.ps1 -ShowCommands` to get current service URLs and credentials
6. **Minikube image loading**: Known Windows issue handled automatically with fallback to Docker Desktop
7. **Directory validation**: Scripts ensure they're running from the correct project directory

### Resource Requirements
- **Minimum**: 2 CPU cores, 4GB RAM, 20GB disk space (enforced by Windows scripts)
- **Recommended**: 4+ CPU cores, 8GB+ RAM for optimal performance
- **Windows Version**: Windows 10/11 with container support (Hyper-V or WSL2)