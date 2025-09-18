# Kubernetes Monitoring Stack Cleanup Script for Windows
# PowerShell equivalent of cleanup.sh

#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

Write-Host "[*] Starting Kubernetes Monitoring Stack Cleanup (Windows)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script cleans up resources deployed by deploy.ps1" -ForegroundColor Gray
Write-Host ""

# Color functions for consistent output
function Write-Success { param([string]$Message) Write-Host "[+] $Message" -ForegroundColor Green }
function Write-Warning { param([string]$Message) Write-Host "[!] $Message" -ForegroundColor Yellow }
function Write-Error { param([string]$Message) Write-Host "[-] $Message" -ForegroundColor Red }
function Write-Info { param([string]$Message) Write-Host "$Message" -ForegroundColor Blue }
function Write-Step { param([string]$Message) Write-Host "$Message" -ForegroundColor Yellow }

# Function to check if command exists
function Test-CommandExists {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Function to test kubectl connectivity with timeout
function Test-KubectlConnectivity {
    try {
        $null = kubectl cluster-info --request-timeout=5s 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

# Function to check if namespace exists
function Test-NamespaceExists {
    param([string]$Namespace)
    kubectl get namespace $Namespace 2>$null | Out-Null
    return $LASTEXITCODE -eq 0
}

# Function to check if helm release exists
function Test-HelmReleaseExists {
    param(
        [string]$Namespace,
        [string]$Release
    )
    try {
        $releases = helm list -n $Namespace -o json | ConvertFrom-Json
        return ($releases | Where-Object { $_.name -eq $Release }) -ne $null
    } catch {
        return $false
    }
}

# Main cleanup function
function Start-Cleanup {
    Write-Step "Step 1: Checking prerequisites..."

    # Check kubectl
    if (-not (Test-CommandExists "kubectl")) {
        Write-Error "kubectl is not installed. Cannot proceed with cleanup."
        exit 1
    }

    # Check Helm
    if (-not (Test-CommandExists "helm")) {
        Write-Warning "Helm not found. Some cleanup operations may be skipped."
    }

    # Test kubectl connectivity
    Write-Info "Testing Kubernetes cluster connectivity..."
    if (Test-KubectlConnectivity) {
        Write-Success "Prerequisites check passed"
    } else {
        Write-Warning "Cannot connect to Kubernetes cluster. This may be due to:"
        Write-Info "1. Minikube cluster issues (will attempt to fix)"
        Write-Info "2. Docker Desktop Kubernetes not enabled"
        Write-Info "3. Network connectivity problems"

        # Try to detect and fix common issues
        if (Test-CommandExists "minikube") {
            Write-Info "Attempting to diagnose minikube issues..."

            try {
                $minikubeStatus = minikube status 2>$null
                if ($minikubeStatus -match "Running") {
                    Write-Warning "Minikube reports running but kubectl cannot connect. Attempting cluster reset..."

                    $response = Read-Host "Reset minikube cluster to fix connectivity? This will delete existing minikube data. (Y/n) [Default: Y]"
                    if ($response -notmatch '^[Nn]$') {
                        Write-Info "Resetting minikube cluster..."
                        minikube delete 2>$null
                        Start-Sleep -Seconds 3
                        Write-Info "This will clean up the broken cluster. Run deploy.ps1 again to recreate it."
                        Write-Success "Minikube cleanup completed. Continuing with resource cleanup..."
                    }
                } else {
                    Write-Info "Minikube is not running. Cleaning up any remaining minikube state..."
                    minikube delete 2>$null
                }
            } catch {
                Write-Warning "Could not diagnose minikube status"
            }
        }

        # Try Docker Desktop context as fallback
        Write-Info "Attempting to switch to Docker Desktop Kubernetes..."
        try {
            kubectl config use-context docker-desktop 2>$null
            if (Test-KubectlConnectivity) {
                Write-Success "Successfully connected using Docker Desktop Kubernetes"
            } else {
                Write-Warning "Kubernetes cluster is not accessible. Will skip Kubernetes resource cleanup."
                Write-Info "You may need to manually clean up resources or enable Kubernetes in Docker Desktop."
                return
            }
        } catch {
            Write-Warning "Could not connect to any Kubernetes cluster. Skipping Kubernetes resource cleanup."
            Write-Info "Manual cleanup may be required if resources were deployed."
            return
        }
    }

    Write-Step "Step 2: Cleaning up demo application..."

    # Try to clean up demo application resources, handling "not found" errors gracefully
    Write-Info "Checking for demo application resources..."

    # Delete ServiceMonitor first (ignore if not found)
    Write-Info "Deleting ServiceMonitor..."
    kubectl delete servicemonitor kube-mon-demo -n app --ignore-not-found=true 2>$null

    # Delete service (ignore if not found)
    Write-Info "Deleting demo app service..."
    kubectl delete service kube-mon-demo -n app --ignore-not-found=true 2>$null

    # Delete deployment (ignore if not found)
    Write-Info "Deleting demo app deployment..."
    kubectl delete deployment kube-mon-demo -n app --ignore-not-found=true 2>$null

    # Wait for pods to terminate (only if namespace exists)
    if (Test-NamespaceExists "app") {
        Write-Info "Waiting for pods to terminate..."
        try {
            kubectl wait --for=delete pods -l app=kube-mon-demo -n app --timeout=60s 2>$null
        } catch {
            Write-Warning "Some pods may still be terminating"
        }

        # Delete app namespace
        Write-Info "Deleting app namespace..."
        kubectl delete namespace app --ignore-not-found=true 2>$null
        Write-Success "Demo application cleanup completed"
    } else {
        Write-Warning "App namespace not found, demo app cleanup completed"
    }

    Write-Step "Step 3: Cleaning up Prometheus alerts..."

    # Delete PrometheusRule for alerts
    Write-Info "Deleting Prometheus alert rules..."
    kubectl delete prometheusrule python-app-alerts -n monitoring --ignore-not-found=true 2>$null

    Write-Step "Step 4: Cleaning up Prometheus Stack..."

    # Check if monitoring namespace exists and if Helm release exists
    if ((Test-NamespaceExists "monitoring") -and (Test-CommandExists "helm")) {
        if (Test-HelmReleaseExists "monitoring" "prometheus-stack") {
            Write-Info "Uninstalling Prometheus stack..."
            try {
                helm uninstall prometheus-stack -n monitoring

                # Wait for pods to terminate
                Write-Info "Waiting for monitoring pods to terminate..."
                try {
                    kubectl wait --for=delete pods --all -n monitoring --timeout=120s
                } catch {
                    Write-Warning "Some monitoring pods may still be terminating"
                }

                Write-Success "Prometheus stack uninstalled"
            } catch {
                Write-Warning "Failed to uninstall Prometheus stack"
            }
        } else {
            Write-Warning "Prometheus stack Helm release not found"
        }

        # Delete any remaining resources in monitoring namespace
        Write-Info "Cleaning up any remaining monitoring resources..."
        try {
            kubectl delete all --all -n monitoring 2>$null
            kubectl delete pvc --all -n monitoring 2>$null
            kubectl delete secrets --all -n monitoring 2>$null
            kubectl delete configmaps --all -n monitoring 2>$null
        } catch {
            # Some resources may not exist, continue
        }

        # Delete monitoring namespace
        Write-Info "Deleting monitoring namespace..."
        kubectl delete namespace monitoring --ignore-not-found=true 2>$null
        Write-Success "Monitoring namespace cleaned up"
    } else {
        if (-not (Test-NamespaceExists "monitoring")) {
            Write-Warning "Monitoring namespace not found, skipping monitoring cleanup"
        }
        if (-not (Test-CommandExists "helm")) {
            Write-Warning "Helm not found, manually cleaning monitoring namespace"
            if (Test-NamespaceExists "monitoring") {
                kubectl delete namespace monitoring --ignore-not-found=true 2>$null
            }
        }
    }

    Write-Step "Step 5: Cleaning up ArgoCD..."

    # Check if ArgoCD namespace exists
    if (Test-NamespaceExists "argocd") {
        Write-Info "Cleaning up ArgoCD resources..."

        # Delete ArgoCD Application
        Write-Info "Deleting ArgoCD Application..."
        kubectl delete application python-monitoring-app -n argocd --ignore-not-found=true 2>$null

        # Delete all ArgoCD resources
        Write-Info "Deleting all ArgoCD resources..."
        kubectl delete all --all -n argocd --ignore-not-found=true 2>$null
        kubectl delete pvc --all -n argocd --ignore-not-found=true 2>$null
        kubectl delete secrets --all -n argocd --ignore-not-found=true 2>$null
        kubectl delete configmaps --all -n argocd --ignore-not-found=true 2>$null

        # Wait for pods to terminate
        Write-Info "Waiting for ArgoCD pods to terminate..."
        try {
            kubectl wait --for=delete pods --all -n argocd --timeout=120s
        } catch {
            Write-Warning "Some ArgoCD pods may still be terminating"
        }

        # Delete ArgoCD namespace
        Write-Info "Deleting argocd namespace..."
        kubectl delete namespace argocd --ignore-not-found=true 2>$null
        Write-Success "ArgoCD resources cleaned up"
    } else {
        Write-Warning "ArgoCD namespace not found, skipping ArgoCD cleanup"
    }

    Write-Step "Step 6: Cleaning up Docker images..."

    # Check if Docker is available
    if ((Test-CommandExists "docker") -and (docker info 2>$null)) {
        $imageName = "your-dockerhub/kube-mon-demo:0.1"

        $imageExists = docker images --format "table {{.Repository}}:{{.Tag}}" 2>$null | Select-String $imageName
        if ($imageExists) {
            Write-Info "Removing Docker image: $imageName"
            docker rmi $imageName 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Docker image removed"
            } else {
                Write-Warning "Failed to remove Docker image"
            }
        } else {
            Write-Warning "Docker image $imageName not found"
        }
    } else {
        Write-Warning "Docker not available, skipping image cleanup"
    }

    Write-Step "Step 7: Cleaning up minikube..."

    # Check if minikube exists
    if (Test-CommandExists "minikube") {
        Write-Info "Checking minikube status..."

        try {
            $status = minikube status 2>$null
            $isRunning = $status -match "Running"
            $isHealthy = Test-KubectlConnectivity

            if ($isRunning -and $isHealthy) {
                Write-Success "Minikube is running and healthy"
                $response = Read-Host "Do you want to stop minikube? [y/N]"
                if ($response -match '^[Yy]$') {
                    Write-Info "Stopping minikube..."
                    try {
                        minikube stop
                        Write-Success "Minikube stopped"
                    } catch {
                        Write-Warning "Failed to stop minikube gracefully"
                    }
                }
            } elseif ($isRunning -and -not $isHealthy) {
                Write-Warning "Minikube is running but cluster is not responding (broken state detected)"
                Write-Info "Recommended: Delete the broken cluster to avoid future issues"

                $response = Read-Host "Delete broken minikube cluster? [Y/n] [Default: Y]"
                if ($response -notmatch '^[Nn]$') {
                    Write-Info "Deleting broken minikube cluster..."
                    try {
                        minikube delete --all
                        Write-Success "Broken minikube cluster deleted"
                    } catch {
                        Write-Warning "Failed to delete minikube cluster cleanly, but will continue"
                    }
                } else {
                    Write-Warning "Broken minikube cluster preserved"
                }
            } else {
                Write-Info "Minikube is not running"

                # Check if there are any leftover minikube profiles
                try {
                    $profiles = minikube profile list -o json 2>$null | ConvertFrom-Json
                    if ($profiles -and $profiles.valid -and $profiles.valid.Count -gt 0) {
                        Write-Info "Found existing minikube profiles: $($profiles.valid -join ', ')"
                        $response = Read-Host "Clean up all minikube profiles and data? [Y/n] [Default: Y]"
                        if ($response -notmatch '^[Nn]$') {
                            Write-Info "Cleaning up all minikube profiles..."
                            minikube delete --all --purge 2>$null
                            Write-Success "All minikube profiles cleaned up"
                        }
                    } else {
                        Write-Info "No minikube profiles found to clean up"
                    }
                } catch {
                    # If we can't list profiles, try a simple delete anyway
                    Write-Info "Attempting basic minikube cleanup..."
                    try {
                        minikube delete 2>$null
                        Write-Info "Basic minikube cleanup completed"
                    } catch {
                        Write-Info "No minikube clusters to clean up"
                    }
                }
            }

            # Final cleanup question for complete removal
            if ($isRunning -or $isHealthy) {
                $response = Read-Host "Do you want to completely delete ALL minikube data and profiles? [y/N]"
                if ($response -match '^[Yy]$') {
                    Write-Info "Performing complete minikube cleanup..."
                    try {
                        minikube delete --all --purge
                        Write-Success "Complete minikube cleanup finished"
                    } catch {
                        Write-Warning "Some minikube cleanup operations may have failed"
                    }
                }
            }

        } catch {
            Write-Warning "Error checking minikube status. Attempting basic cleanup..."
            try {
                minikube delete --all 2>$null
                Write-Info "Basic minikube cleanup attempted"
            } catch {
                Write-Warning "Could not perform minikube cleanup"
            }
        }
    } else {
        Write-Warning "Minikube not found, skipping minikube cleanup"
    }

    Write-Step "Step 8: Final verification..."

    # Check for remaining resources
    Write-Info "Checking for remaining resources..."

    $remainingNamespaces = @()
    if (Test-NamespaceExists "app") { $remainingNamespaces += "app" }
    if (Test-NamespaceExists "monitoring") { $remainingNamespaces += "monitoring" }
    if (Test-NamespaceExists "argocd") { $remainingNamespaces += "argocd" }

    if ($remainingNamespaces.Count -gt 0) {
        Write-Warning "Some namespaces still exist: $($remainingNamespaces -join ', ')"
        Write-Info "This might be normal if they're in 'Terminating' state"
    } else {
        Write-Success "All target namespaces have been removed"
    }

    Write-Host ""
    Write-Success "Cleanup completed!"
    Write-Host "===================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: To redeploy the monitoring stack, run: .\deploy.ps1" -ForegroundColor Yellow
    Write-Host "Note: If you see namespaces in 'Terminating' state, this is normal." -ForegroundColor Yellow
    Write-Host ""
    Write-Success "Your cluster is now clean!"
}

# Run the cleanup
Start-Cleanup