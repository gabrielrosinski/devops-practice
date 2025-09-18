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

- **`status.sh`** - Quick deployment status check
  - Shows component deployment status (replicas ready)
  - Displays service access URLs and port-forward commands
  - Automatically retrieves and displays login credentials
  - Quick launch commands for all services

- **`healthcheck.sh`** - Real-time health monitoring and service discovery
  - Single comprehensive health check
  - Continuous monitoring with customizable refresh rates
  - Service connectivity testing
  - Automatic credential retrieval and access URL generation

## Usage

From the project root directory:

```bash
# Deploy the monitoring stack
linux/deploy.sh

# Check deployment status and get access information
linux/status.sh

# Real-time health monitoring
linux/healthcheck.sh

# Clean up all resources
linux/cleanup.sh
```

## Advanced Usage

### Health Monitoring Options

```bash
# Single comprehensive health check
linux/healthcheck.sh

# Show all access commands and credentials
linux/healthcheck.sh --show-commands

# Test localhost port connectivity
linux/healthcheck.sh --test-connectivity

# Continuous monitoring with default refresh (10s)
linux/healthcheck.sh --continuous

# Continuous monitoring with custom refresh rate
linux/healthcheck.sh --continuous --refresh 5

# Combined options
linux/healthcheck.sh --show-commands --test-connectivity
linux/healthcheck.sh --continuous --refresh 15
```

### Service Status Check

```bash
# Quick status check with credentials
linux/status.sh
```

## Prerequisites

- Docker (must be running)
- kubectl CLI tool
- Helm (automatically installed if missing)
- Minimum system requirements: 2 CPU cores, 4GB RAM, 20GB free disk space

## Features

### Enhanced Monitoring Capabilities
- **Real-time health monitoring**: Live service health dashboard with connectivity testing
- **Service discovery**: Automatic credential retrieval and access URL generation
- **Flexible connectivity testing**: Multiple methods for port connectivity validation (netcat, bash TCP redirection)
- **Continuous monitoring**: Customizable refresh rates for real-time monitoring
- **Cross-platform compatibility**: Works on both Linux and macOS with automatic platform detection

### System Validation
- **Resource enforcement**: Validates minimum system requirements (2+ CPU cores, 4GB+ RAM, 20GB+ disk space)
- **Hard requirement stops**: Deployment will not proceed on systems that don't meet minimum viable resources
- **Automatic platform detection**: Detects Linux vs macOS and uses appropriate system commands

### User Experience
- **Color-coded output**: Clear visual indicators for status (green=success, yellow=warning, red=error)
- **Comprehensive error handling**: Graceful degradation when tools are missing
- **Flexible usage**: Support for single checks, continuous monitoring, and combined options

## Support

These scripts support both Linux and macOS environments with automatic platform detection for system resource checks.