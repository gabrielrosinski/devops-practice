# Linux/macOS Deployment Scripts

This directory contains the deployment scripts for Linux and macOS systems.

## Scripts

- **`deploy.sh`** - Main deployment script that sets up the entire Kubernetes monitoring stack
  - Validates system requirements (2+ CPU cores, 4GB+ RAM, 20GB+ disk space)
  - Deploys demo application, Prometheus, Grafana, and ArgoCD
  - Builds and loads the demo application Docker image
  - Configures monitoring and alerting rules

- **`cleanup.sh`** - Comprehensive cleanup script
  - Removes all deployed Kubernetes resources
  - Cleans up Docker images
  - Optional minikube cluster deletion
  - Handles graceful termination of all components

## Usage

From the project root directory:

```bash
# Deploy the monitoring stack
linux/deploy.sh

# Clean up all resources
linux/cleanup.sh
```

## Prerequisites

- Docker (must be running)
- kubectl CLI tool
- Helm (automatically installed if missing)
- Minimum system requirements: 2 CPU cores, 4GB RAM, 20GB free disk space

## Support

These scripts support both Linux and macOS environments with automatic platform detection for system resource checks.