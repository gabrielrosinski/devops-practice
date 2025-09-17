# Windows PowerShell Deployment Scripts

This directory contains the enhanced PowerShell deployment scripts for Windows systems.

## Scripts

- **`deploy.ps1`** - Main deployment script with Windows-specific enhancements
  - System validation and auto-elevation for dependency installation
  - Validates system requirements (2+ CPU cores, 4GB+ RAM, 20GB+ disk space, Windows 10/11)
  - Auto-installs missing dependencies (Docker Desktop, kubectl, Helm, ArgoCD CLI)
  - Enhanced error handling for Windows-specific Kubernetes issues
  - Deployment summary with access information

- **`cleanup.ps1`** - Comprehensive cleanup script
  - Removes all deployed Kubernetes resources
  - Handles broken minikube cluster detection and recovery
  - Interactive prompts for destructive operations
  - Cross-context cleanup (minikube and Docker Desktop)

- **`healthcheck.ps1`** - Real-time health monitoring and service discovery
  - Single comprehensive health check
  - Continuous monitoring with customizable refresh rates
  - Service connectivity testing
  - Automatic credential retrieval and access URL generation

- **`status.ps1`** - Quick deployment status check
  - Shows component deployment status (replicas ready)
  - Displays service access URLs and port-forward commands
  - Automatically retrieves and displays login credentials
  - Quick launch commands for all services

## Usage

From the project root directory:

```powershell
# Deploy the monitoring stack
windows\deploy.ps1

# Check deployment status and get access information
windows\status.ps1

# Real-time health monitoring
windows\healthcheck.ps1

# Clean up all resources
windows\cleanup.ps1
```

## Advanced Usage

```powershell
# Continuous health monitoring with custom refresh rate
windows\healthcheck.ps1 -Continuous -RefreshSeconds 5

# Show all access commands and credentials
windows\healthcheck.ps1 -ShowCommands

# Test localhost port connectivity
windows\healthcheck.ps1 -TestConnectivity
```

## Prerequisites

- Windows 10/11 with container support (Hyper-V or WSL2)
- PowerShell 5.1 or higher
- Minimum system requirements: 2 CPU cores, 4GB RAM, 20GB free disk space
- Docker Desktop with Kubernetes enabled (auto-installed if missing)

## Windows-Specific Features

- **Auto-elevation**: Automatic administrator privilege request when needed
- **Smart dependency management**: Auto-installs missing tools via Chocolatey/winget
- **Enhanced error handling**: Graceful degradation and recovery for common Windows issues
- **Real-time monitoring**: Live service health dashboard with connectivity testing
- **Service discovery**: Automatic credential retrieval and access URL generation
- **Minikube issue resolution**: Automatic detection and fixing of Windows minikube problems