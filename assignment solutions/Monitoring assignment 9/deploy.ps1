# Kubernetes Monitoring Stack Deployment Script for Windows
# PowerShell equivalent of deploy.sh

#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$NoElevate
)

$ErrorActionPreference = "Stop"

# Check if running as administrator and auto-elevate if needed
if (-not $NoElevate) {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "[!] Administrator privileges required for automatic dependency installation." -ForegroundColor Yellow

        # Ask user if they want to elevate or continue without admin
        $response = Read-Host "Elevate to administrator? (Y/n) [Default: Y]"
        if ($response -match '^[Nn]$') {
            Write-Host "[*] Continuing without elevation. Manual dependency installation may be required." -ForegroundColor Yellow
            return
        }

        Write-Host "[*] Attempting to restart script with administrator privileges..." -ForegroundColor Cyan

        try {
            # Get the current script path and working directory
            $scriptPath = $MyInvocation.MyCommand.Path
            $currentDirectory = Get-Location

            # Restart the script with admin privileges, preserving the working directory
            $arguments = "-ExecutionPolicy Bypass -Command `"Set-Location '$currentDirectory'; & '$scriptPath'`""
            Start-Process PowerShell -Verb RunAs -ArgumentList $arguments -Wait
            exit 0
        } catch {
            Write-Host "[-] Failed to elevate privileges automatically." -ForegroundColor Red
            Write-Host "[!] Please run PowerShell as Administrator manually, or install dependencies manually:" -ForegroundColor Yellow
            Write-Host "    1. Docker Desktop: https://www.docker.com/products/docker-desktop" -ForegroundColor White
            Write-Host "    2. kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/" -ForegroundColor White
            Write-Host "    3. Helm: https://helm.sh/docs/intro/install/" -ForegroundColor White
            Write-Host "    4. ArgoCD CLI: https://argo-cd.readthedocs.io/en/stable/cli_installation/" -ForegroundColor White
            Write-Host ""
            Write-Host "[*] Then run: .\deploy.ps1 -NoElevate" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Press any key to exit..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit 1
        }
    }
}

Write-Host "[*] Starting Kubernetes Monitoring Stack Deployment (Windows)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Color definitions for consistent output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Success { param([string]$Message) Write-ColorOutput "[+] $Message" "Green" }
function Write-Warning { param([string]$Message) Write-ColorOutput "[!] $Message" "Yellow" }
function Write-Error { param([string]$Message) Write-ColorOutput "[-] $Message" "Red" }
function Write-Info { param([string]$Message) Write-ColorOutput "$Message" "Blue" }
function Write-Step { param([string]$Message) Write-ColorOutput "$Message" "Yellow" }

# Function to exit gracefully with pause
function Exit-WithPause {
    param(
        [string]$Message = "",
        [int]$ExitCode = 1
    )

    if ($Message) {
        Write-Host ""
        Write-Host "=" * 80 -ForegroundColor Red
        Write-Error $Message
        Write-Host "=" * 80 -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit $ExitCode
}

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

# Function to check if running as administrator
function Test-IsAdmin {
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

# Function to check system requirements
function Test-SystemRequirements {
    Write-Step "Step 0: Validating system requirements..."

    $requirements = @{
        MinCores = 2
        MinRAMGB = 4
        MinDiskGB = 20
    }

    # Check CPU cores (HARD REQUIREMENT)
    $cores = (Get-WmiObject -Class Win32_Processor | Measure-Object -Property NumberOfCores -Sum).Sum
    if ($cores -lt $requirements.MinCores) {
        Exit-WithPause "INSUFFICIENT CPU CORES: Found $cores cores, but minimum $($requirements.MinCores) cores required. This system does not meet the minimum viable resource requirements. Please use a system with at least $($requirements.MinCores) CPU cores."
    } else {
        Write-Success "CPU cores requirement met: $cores cores (minimum: $($requirements.MinCores))"
    }

    # Check RAM (HARD REQUIREMENT)
    $totalRAMGB = [math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    if ($totalRAMGB -lt $requirements.MinRAMGB) {
        Exit-WithPause "INSUFFICIENT RAM: Found ${totalRAMGB}GB, but minimum $($requirements.MinRAMGB)GB required. This system does not meet the minimum viable resource requirements. Please use a system with at least $($requirements.MinRAMGB)GB of RAM."
    } else {
        Write-Success "RAM requirement met: ${totalRAMGB}GB (minimum: $($requirements.MinRAMGB)GB)"
    }

    # Check disk space (HARD REQUIREMENT)
    $systemDrive = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $env:SystemDrive }
    $freeDiskGB = [math]::Round($systemDrive.FreeSpace / 1GB, 1)
    if ($freeDiskGB -lt $requirements.MinDiskGB) {
        Exit-WithPause "INSUFFICIENT DISK SPACE: Found ${freeDiskGB}GB free, but minimum $($requirements.MinDiskGB)GB required. This system does not meet the minimum viable resource requirements. Please free up disk space or use a system with at least $($requirements.MinDiskGB)GB available."
    } else {
        Write-Success "Disk space requirement met: ${freeDiskGB}GB free (minimum: $($requirements.MinDiskGB)GB)"
    }

    # Check Windows version
    $osInfo = Get-ComputerInfo -Property WindowsProductName, WindowsVersion
    Write-Info "Windows Version: $($osInfo.WindowsProductName) $($osInfo.WindowsVersion)"

    # Check virtualization support (may require elevation)
    try {
        $hyperV = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction Stop
        if ($hyperV -and $hyperV.State -eq "Enabled") {
            Write-Success "Hyper-V is enabled"
        } else {
            Write-Warning "Hyper-V not enabled. Docker Desktop may use WSL2 backend"
        }
    } catch {
        Write-Warning "Cannot check Hyper-V status (requires admin privileges). Docker Desktop will auto-configure backend"
    }

    Write-Success "ALL SYSTEM REQUIREMENTS MET - Proceeding with deployment"
    Write-Info "System meets minimum viable resources: $cores cores, ${totalRAMGB}GB RAM, ${freeDiskGB}GB free"
}

# Function to check minikube status
function Test-MinikubeStatus {
    if (Test-CommandExists "minikube") {
        try {
            $status = minikube status --format="{{.Host}}" 2>$null
            return $status -eq "Running"
        } catch {
            return $false
        }
    }
    return $false
}

# Function to wait for deployment
function Wait-ForDeployment {
    param(
        [string]$Namespace,
        [string]$Deployment,
        [int]$TimeoutSeconds = 300
    )

    Write-Info "Waiting for deployment $Deployment in namespace $Namespace..."
    try {
        kubectl wait --for=condition=available --timeout="${TimeoutSeconds}s" deployment/$Deployment -n $Namespace
        Write-Success "Deployment $Deployment is ready"
    } catch {
        Write-Warning "Deployment $Deployment may still be starting up"
    }
}

# Function to wait for pods
function Wait-ForPods {
    param(
        [string]$Namespace,
        [string]$Label,
        [int]$TimeoutSeconds = 300
    )

    Write-Info "Waiting for pods with label $Label in namespace $Namespace..."
    try {
        kubectl wait --for=condition=ready --timeout="${TimeoutSeconds}s" pods -l $Label -n $Namespace
        Write-Success "Pods with label $Label are ready"
    } catch {
        Write-Warning "Pods with label $Label may still be starting up"
    }
}

# Function to install missing dependencies
function Install-Dependencies {
    Write-Step "Step 1: Checking and installing dependencies..."

    # Check if running as admin (should be true now due to auto-elevation)
    $isAdmin = Test-IsAdmin
    if ($isAdmin) {
        Write-Success "Running with administrator privileges - automatic installation enabled"
    } else {
        Write-Warning "Not running as administrator. Dependency installation may be limited."
    }

    # Check for package managers
    $hasChoco = Test-CommandExists "choco"
    $hasWinget = Test-CommandExists "winget"

    if (-not $hasChoco -and -not $hasWinget) {
        if ($isAdmin) {
            Write-Warning "Neither Chocolatey nor winget found. Installing Chocolatey..."
            try {
                Set-ExecutionPolicy Bypass -Scope Process -Force
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
                $hasChoco = $true
            } catch {
                Write-Error "Failed to install Chocolatey. Please install dependencies manually."
                exit 1
            }
        } else {
            Write-Warning "No package manager found and not running as admin. Please install dependencies manually:"
            Write-Info "1. Docker Desktop: https://www.docker.com/products/docker-desktop"
            Write-Info "2. kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
            Write-Info "3. Helm: https://helm.sh/docs/intro/install/"
            Write-Info "4. ArgoCD CLI: https://argo-cd.readthedocs.io/en/stable/cli_installation/"
            Write-Info "Then re-run this script."
            exit 1
        }
    }

    # Check Docker
    if (-not (Test-CommandExists "docker")) {
        if ($isAdmin -and ($hasChoco -or $hasWinget)) {
            Write-Warning "Docker not found. Installing Docker Desktop..."
            try {
                if ($hasChoco) {
                    choco install docker-desktop -y
                } elseif ($hasWinget) {
                    winget install Docker.DockerDesktop
                }
            } catch {
                Write-Warning "Failed to install Docker Desktop automatically. Please install manually."
            }
        } else {
            Exit-WithPause "Docker Desktop is not installed. Please install it manually from: https://www.docker.com/products/docker-desktop. After installation, enable Kubernetes in Docker Desktop settings."
        }
    }

    # Check if Docker is running
    try {
        docker info | Out-Null
        Write-Success "Docker is installed and running"
    } catch {
        Write-Error "Docker is not running. Please start Docker Desktop and ensure Kubernetes is enabled."
        Write-Info "To enable Kubernetes in Docker Desktop:"
        Write-Info "1. Open Docker Desktop"
        Write-Info "2. Go to Settings -> Kubernetes"
        Write-Info "3. Check 'Enable Kubernetes'"
        Write-Info "4. Click 'Apply & Restart'"
        exit 1
    }

    # Check kubectl
    if (-not (Test-CommandExists "kubectl")) {
        if ($isAdmin -and ($hasChoco -or $hasWinget)) {
            Write-Warning "kubectl not found. Installing kubectl..."
            try {
                if ($hasChoco) {
                    choco install kubernetes-cli -y
                } elseif ($hasWinget) {
                    winget install Kubernetes.kubectl
                }
            } catch {
                Write-Warning "Failed to install kubectl automatically. Please install manually."
            }
        } else {
            Write-Error "kubectl is not installed. Please install it manually:"
            Write-Info "Download from: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
            exit 1
        }
    }

    if (Test-CommandExists "kubectl") {
        Write-Success "kubectl is installed"
    } else {
        Write-Error "kubectl installation failed or not found in PATH"
        exit 1
    }

    # Check Helm
    if (-not (Test-CommandExists "helm")) {
        if ($isAdmin -and ($hasChoco -or $hasWinget)) {
            Write-Warning "Helm not found. Installing Helm..."
            try {
                if ($hasChoco) {
                    choco install kubernetes-helm -y
                } elseif ($hasWinget) {
                    winget install Helm.Helm
                }
            } catch {
                Write-Warning "Failed to install Helm automatically. Please install manually."
            }
        } else {
            Write-Error "Helm is not installed. Please install it manually:"
            Write-Info "Download from: https://helm.sh/docs/intro/install/"
            exit 1
        }
    }

    if (Test-CommandExists "helm") {
        Write-Success "Helm is installed"
    } else {
        Write-Error "Helm installation failed or not found in PATH"
        exit 1
    }

    # Check ArgoCD CLI
    if (-not (Test-CommandExists "argocd")) {
        Write-Warning "ArgoCD CLI not found. Installing ArgoCD CLI..."
        if ($hasChoco) {
            choco install argocd-cli -y
        } else {
            Write-Info "Installing ArgoCD CLI manually..."
            $argocdUrl = "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-windows-amd64.exe"
            $argocdPath = "$env:USERPROFILE\argocd.exe"
            try {
                Invoke-WebRequest -Uri $argocdUrl -OutFile $argocdPath
                Write-Success "ArgoCD CLI downloaded to $argocdPath"
                Write-Warning "Add $env:USERPROFILE to your PATH to use 'argocd' command globally"
            } catch {
                Write-Warning "Failed to download ArgoCD CLI automatically"
            }
        }
    } else {
        Write-Success "ArgoCD CLI is installed"
    }

    # Check minikube (optional)
    if (Test-CommandExists "minikube") {
        Write-Success "Minikube is installed"

        if (-not (Test-MinikubeStatus)) {
            Write-Warning "Starting minikube with enhanced error handling..."

            # Try to clean up any corrupted minikube state first
            Write-Info "Cleaning up any previous minikube state..."
            try {
                minikube delete 2>$null
                Start-Sleep -Seconds 3
            } catch {
                # Ignore errors during cleanup
            }

            Write-Info "Starting fresh minikube instance..."
            try {
                # Start minikube with specific parameters to avoid common issues
                minikube start --driver=docker --kubernetes-version=v1.28.0 --memory=4096 --cpus=2 --disk-size=20g

                # Wait a moment for API server to be ready
                Write-Info "Waiting for Kubernetes API server to be ready..."
                Start-Sleep -Seconds 10

                # Test if kubectl can connect
                $testResult = kubectl cluster-info --request-timeout=30s 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Info "Enabling metrics-server addon..."
                    minikube addons enable metrics-server
                    Write-Success "Minikube started successfully"
                } else {
                    throw "Kubernetes API server not responding"
                }
            } catch {
                Write-Warning "Failed to start minikube properly. Error: $($_.Exception.Message)"
                Write-Warning "Minikube may have networking issues. Trying Docker Desktop Kubernetes instead..."

                # Clean up failed minikube
                try {
                    minikube delete 2>$null
                } catch {
                    # Ignore cleanup errors
                }

                # Check if Docker Desktop Kubernetes is available
                try {
                    kubectl cluster-info --context=docker-desktop --request-timeout=10s | Out-Null
                    Write-Info "Switching to Docker Desktop Kubernetes context..."
                    kubectl config use-context docker-desktop
                    Write-Success "Using Docker Desktop Kubernetes instead of minikube"
                } catch {
                    Exit-WithPause "Neither minikube nor Docker Desktop Kubernetes is working. Please ensure Docker Desktop has Kubernetes enabled in Settings > Kubernetes > Enable Kubernetes."
                }
            }
        } else {
            Write-Success "Minikube is already running"

            # Verify minikube is actually working
            try {
                kubectl cluster-info --request-timeout=10s | Out-Null
                Write-Success "Minikube cluster is responding"
            } catch {
                Write-Warning "Minikube is running but cluster is not responding. Attempting restart..."
                try {
                    minikube delete
                    Start-Sleep -Seconds 3
                    minikube start --driver=docker --kubernetes-version=v1.28.0 --memory=4096 --cpus=2
                    Start-Sleep -Seconds 10
                    minikube addons enable metrics-server
                    Write-Success "Minikube restarted successfully"
                } catch {
                    Exit-WithPause "Failed to restart minikube. Please check Docker Desktop settings or try running: minikube delete && minikube start"
                }
            }
        }
    } else {
        Write-Warning "Minikube not found. Using Docker Desktop Kubernetes."

        # Verify Docker Desktop Kubernetes is available
        try {
            kubectl cluster-info --context=docker-desktop --request-timeout=10s | Out-Null
            kubectl config use-context docker-desktop
            Write-Success "Using Docker Desktop Kubernetes"
        } catch {
            Exit-WithPause "Docker Desktop Kubernetes is not available. Please enable Kubernetes in Docker Desktop Settings > Kubernetes > Enable Kubernetes."
        }
    }
}

# Function to validate and fix script location
function Test-ScriptLocation {
    $requiredFiles = @(
        "k8s/namespace.yaml",
        "k8s/deployment.yaml",
        "k8s/service.yaml",
        "k8s/servicemonitor.yaml",
        "test_app/Dockerfile",
        "test_app/main.py",
        "prometheus/prometheus-alerts.yaml",
        "argocd.yaml"
    )

    $currentLocation = Get-Location
    Write-Info "Validating script location: $currentLocation"

    # Check if we're in the right directory
    $missingFiles = @()
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            $missingFiles += $file
        }
    }

    if ($missingFiles.Count -gt 0) {
        Write-Warning "Required files not found in current directory. Attempting to locate project directory..."

        # Try to find the correct directory based on script location
        $scriptDirectory = Split-Path $MyInvocation.MyCommand.Path -Parent
        Write-Info "Script is located at: $scriptDirectory"

        # Try changing to script directory
        try {
            Set-Location $scriptDirectory
            Write-Info "Changed to script directory: $scriptDirectory"

            # Re-check files
            $stillMissingFiles = @()
            foreach ($file in $requiredFiles) {
                if (-not (Test-Path $file)) {
                    $stillMissingFiles += $file
                }
            }

            if ($stillMissingFiles.Count -eq 0) {
                Write-Success "Found all required files in script directory"
                return
            }
        } catch {
            Write-Warning "Could not change to script directory"
        }

        # If we still can't find files, show error
        Write-Error "Script is not running from the correct directory!"
        Write-Error "Current directory: $(Get-Location)"
        Write-Error "Script directory: $scriptDirectory"
        Write-Error "Missing required files:"
        foreach ($file in $missingFiles) {
            Write-Error "  - $file"
        }
        Write-Info ""
        Write-Info "Please ensure you are running the script from the project root directory:"
        Write-Info "  cd 'C:\devops-practice\assignment solutions\Monitoring assignment 9'"
        Write-Info "  .\deploy.ps1"
        Write-Info ""
        Write-Info "Or try running from the same directory as the script:"
        Write-Info "  cd '$scriptDirectory'"
        Write-Info "  .\deploy.ps1"
        Exit-WithPause "Script must be run from the project root directory containing the k8s/ and test_app/ folders."
    }

    Write-Success "All required files found - script location validated"
}

# Main deployment function
function Start-Deployment {
    # Validate we're in the correct directory first
    Test-ScriptLocation

    # Test system requirements
    Test-SystemRequirements

    # Install dependencies
    Install-Dependencies

    # Test kubectl connectivity
    Write-Info "Testing Kubernetes connectivity..."
    try {
        kubectl cluster-info | Out-Null
        Write-Success "Kubernetes cluster is accessible"
    } catch {
        Write-Error "Cannot connect to Kubernetes cluster. Please ensure your cluster is running."
        exit 1
    }

    Write-Step "Step 2: Building Docker image and applying Kubernetes manifests..."

    # Apply namespaces first
    Write-Info "Creating namespaces..."
    kubectl apply -f k8s/namespace.yaml

    # Navigate to test app directory
    Write-Info "Building Docker image..."
    try {
        if (-not (Test-Path "test_app")) {
            throw "test_app directory not found"
        }

        Push-Location test_app

        # Build Docker image
        $imageName = "your-dockerhub/kube-mon-demo:0.1"
        $imageExists = docker images --format "table {{.Repository}}:{{.Tag}}" | Select-String $imageName

        if ($imageExists) {
            Write-Success "Docker image $imageName already exists"
        } else {
            Write-Info "Building Docker image from test_app directory..."
            docker build -t $imageName .

            if ($LASTEXITCODE -ne 0) {
                throw "Docker build failed"
            }
            Write-Success "Docker image built successfully"
        }

        # Load image into minikube if using minikube
        if (Test-MinikubeStatus) {
            Write-Info "Loading image into minikube..."
            try {
                # Try to load the image into minikube
                minikube image load $imageName 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Image loaded into minikube successfully"
                } else {
                    throw "minikube image load failed"
                }
            } catch {
                Write-Warning "Failed to load image into minikube (this is a known Windows issue)"
                Write-Info "Continuing deployment - Kubernetes will pull the image from Docker Desktop's registry"
                Write-Info "Alternative: Using Docker Desktop's built-in registry for minikube"

                # Try alternative approach - build image directly in minikube
                try {
                    Write-Info "Attempting to build image directly in minikube environment..."
                    minikube docker-env | Invoke-Expression
                    docker build -t $imageName . 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Image built directly in minikube environment"
                    } else {
                        Write-Warning "Alternative build method also failed"
                        Write-Info "Deployment will continue with imagePullPolicy: IfNotPresent"
                    }
                } catch {
                    Write-Warning "Alternative image loading failed. Continuing with Docker Desktop registry."
                    Write-Info "Note: Ensure Docker Desktop is running and image is available locally"
                }
            }
        }

    } catch {
        Write-Error "Failed to build Docker image: $($_.Exception.Message)"
        throw
    } finally {
        # Always return to parent directory
        try {
            Pop-Location
        } catch {
            # If Pop-Location fails, try to get back to script directory
            Set-Location (Split-Path $MyInvocation.MyCommand.Path)
        }
    }

    Write-Info "Applying Kubernetes manifests..."
    kubectl apply -f k8s/deployment.yaml
    kubectl apply -f k8s/service.yaml

    # Check if pods are having image pull issues
    Write-Info "Checking pod status..."
    Start-Sleep -Seconds 5

    $podStatus = kubectl get pods -n app -l app=kube-mon-demo -o jsonpath='{.items[0].status.containerStatuses[0].state}' 2>$null
    if ($podStatus -match "ErrImagePull" -or $podStatus -match "ImagePullBackOff") {
        Write-Warning "Pods are having image pull issues. This is likely due to the minikube image loading failure."
        Write-Info "Attempting to fix by switching to Docker Desktop context..."

        try {
            # Switch to Docker Desktop context where the image should be available
            kubectl config use-context docker-desktop
            Write-Info "Switched to Docker Desktop Kubernetes context"

            # Delete existing deployment and reapply
            kubectl delete deployment kube-mon-demo -n app --ignore-not-found=true
            Start-Sleep -Seconds 5
            kubectl apply -f k8s/deployment.yaml

            Write-Success "Redeployed using Docker Desktop context"
        } catch {
            Write-Warning "Could not switch to Docker Desktop. Continuing with minikube..."
        }
    }

    # Wait for demo app to be ready
    Wait-ForDeployment "app" "kube-mon-demo"

    Write-Step "Step 3: Installing Prometheus Stack..."

    # Add Prometheus Helm repository
    $repoExists = helm repo list | Select-String "prometheus-community"
    if (-not $repoExists) {
        Write-Info "Adding Prometheus Helm repository..."
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    }

    helm repo update

    # Check if Prometheus stack is already installed
    $stackExists = helm list -n monitoring | Select-String "prometheus-stack"
    if ($stackExists) {
        Write-Success "Prometheus stack is already installed"
    } else {
        Write-Info "Installing Prometheus stack..."
        helm install prometheus-stack prometheus-community/kube-prometheus-stack `
            --namespace monitoring `
            --create-namespace `
            --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
    }

    # Wait for Prometheus operator
    Wait-ForDeployment "monitoring" "prometheus-stack-kube-prom-operator"

    Write-Info "Waiting for all monitoring components to be ready..."
    Start-Sleep -Seconds 30

    Wait-ForPods "monitoring" "app.kubernetes.io/name=prometheus" 180
    Wait-ForPods "monitoring" "app.kubernetes.io/name=grafana" 180

    Write-Step "Step 4: Applying ServiceMonitor and Alerts..."

    kubectl apply -f k8s/servicemonitor.yaml
    kubectl apply -f prometheus/prometheus-alerts.yaml

    Write-Step "Step 5: Installing ArgoCD..."

    # Get current context for better logging
    $currentContext = kubectl config current-context 2>$null
    Write-Info "Current Kubernetes context: $currentContext"

    # Check if ArgoCD namespace exists
    $argoCDNamespaceExists = $false
    try {
        kubectl get namespace argocd | Out-Null
        $argoCDNamespaceExists = $true
        Write-Success "ArgoCD namespace already exists"
    } catch {
        Write-Info "Creating ArgoCD namespace..."
        kubectl create namespace argocd
        $argoCDNamespaceExists = $true
    }

    # Check if ArgoCD is actually installed and functional
    $argoCDInstalled = $false
    if ($argoCDNamespaceExists) {
        try {
            # Check for the main ArgoCD server deployment
            $deployment = kubectl get deployment argocd-server -n argocd -o jsonpath='{.status.readyReplicas}' 2>$null
            if ($deployment -and $deployment -gt 0) {
                Write-Success "ArgoCD is already installed and running ($deployment replicas ready)"
                $argoCDInstalled = $true
            } else {
                Write-Warning "ArgoCD namespace exists but server deployment is not ready"
            }
        } catch {
            Write-Info "ArgoCD deployment not found or not ready"
        }

        # Also check if the basic resources exist
        if (-not $argoCDInstalled) {
            try {
                $services = kubectl get svc -n argocd --no-headers 2>$null | Measure-Object | Select-Object -ExpandProperty Count
                if ($services -gt 0) {
                    Write-Info "Found $services ArgoCD services, but deployment may be starting up..."
                    Write-Info "Skipping installation - ArgoCD appears to be present"
                    $argoCDInstalled = $true
                }
            } catch {
                Write-Info "No ArgoCD services found"
            }
        }
    }

    if (-not $argoCDInstalled) {
        Write-Info "Installing ArgoCD in context: $currentContext"
        try {
            kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
            Write-Success "ArgoCD installation initiated"
        } catch {
            Write-Warning "Failed to install ArgoCD: $($_.Exception.Message)"
        }
    }

    Wait-ForDeployment "argocd" "argocd-server"
    Wait-ForPods "argocd" "app.kubernetes.io/name=argocd-server" 180

    Write-Step "Step 6: Configuring ArgoCD Application..."

    # Get ArgoCD password
    try {
        $argocdPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
    } catch {
        $argocdPassword = ""
    }

    if ($argocdPassword) {
        Write-Info "Configuring ArgoCD Application..."

        # Start port-forward in background
        $portForwardJob = Start-Job -ScriptBlock {
            kubectl port-forward svc/argocd-server -n argocd 8080:443
        }

        Start-Sleep -Seconds 5

        # Apply ArgoCD application
        try {
            kubectl apply -f argocd.yaml
            Write-Success "ArgoCD Application created successfully"
        } catch {
            Write-Warning "Failed to create ArgoCD Application automatically"
        }

        # Clean up port-forward
        Stop-Job $portForwardJob -ErrorAction SilentlyContinue
        Remove-Job $portForwardJob -ErrorAction SilentlyContinue
    } else {
        Write-Warning "ArgoCD password not available, skipping automatic app creation"
    }

    # Display access information
    Write-Success "Deployment completed successfully!"
    Write-Host ""
    Write-Info "[*] Access Information:"
    Write-Host "====================" -ForegroundColor Blue
    Write-Host ""

    Write-Host "To access Prometheus:" -ForegroundColor Yellow
    Write-Host "  kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090"
    Write-Host "  Then open: http://localhost:9090"
    Write-Host ""

    Write-Host "To access Grafana:" -ForegroundColor Yellow
    Write-Host "  kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80"
    Write-Host "  Then open: http://localhost:3000"
    Write-Host "  Username: admin"
    try {
        $grafanaPassword = kubectl get secret --namespace monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
        Write-Host "  Password: $grafanaPassword"
    } catch {
        Write-Host "  Password: (run kubectl get secret --namespace monitoring prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 --decode)"
    }
    Write-Host ""

    Write-Host "To access Demo App:" -ForegroundColor Yellow
    Write-Host "  kubectl port-forward -n app svc/kube-mon-demo 8000:80"
    Write-Host "  Then open: http://localhost:8000"
    Write-Host ""

    Write-Host "To access ArgoCD:" -ForegroundColor Yellow
    Write-Host "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    Write-Host "  Then open: https://localhost:8080"
    Write-Host "  Username: admin"
    if ($argocdPassword) {
        Write-Host "  Password: $argocdPassword"
    } else {
        Write-Host "  Password: (run kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode)"
    }
    Write-Host ""

    Write-Host "[!] IMPORTANT: Manually import the Grafana dashboard" -ForegroundColor Blue
    Write-Host "To see alerts and application monitoring:" -ForegroundColor Yellow
    Write-Host "  1. Open Grafana at http://localhost:3000"
    Write-Host "  2. Go to Dashboards -> Import"
    Write-Host "  3. Upload the grafana-dashboard.json file from this directory"
    Write-Host "  4. The dashboard includes application alerts, restart monitoring, and metrics"
    Write-Host ""

    Write-Success "All services are ready!"
    Write-Host ""
    Write-Info "[!] Tip: Run .\healthcheck.ps1 to monitor service health and get access URLs"
    Write-Host ""

    # Show deployment summary
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host "DEPLOYMENT SUMMARY" -ForegroundColor Green
    Write-Host "=" * 80 -ForegroundColor Green

    # Check current context
    $currentContext = kubectl config current-context 2>$null
    Write-Host "Kubernetes Context: $currentContext" -ForegroundColor Cyan

    # Check component status
    Write-Host ""
    Write-Host "Component Status:" -ForegroundColor Yellow

    # Demo App
    try {
        $demoStatus = kubectl get deployment kube-mon-demo -n app -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>$null
        Write-Host "  Demo App: $demoStatus replicas ready" -ForegroundColor Green
    } catch {
        Write-Host "  Demo App: Not found or not ready" -ForegroundColor Red
    }

    # Prometheus
    try {
        $prometheusStatus = kubectl get statefulset prometheus-prometheus-stack-kube-prom-prometheus -n monitoring -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>$null
        Write-Host "  Prometheus: $prometheusStatus replicas ready" -ForegroundColor Green
    } catch {
        Write-Host "  Prometheus: Not found or not ready" -ForegroundColor Red
    }

    # Grafana
    try {
        $grafanaStatus = kubectl get deployment prometheus-stack-grafana -n monitoring -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>$null
        Write-Host "  Grafana: $grafanaStatus replicas ready" -ForegroundColor Green
    } catch {
        Write-Host "  Grafana: Not found or not ready" -ForegroundColor Red
    }

    # ArgoCD
    try {
        $argocdStatus = kubectl get deployment argocd-server -n argocd -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>$null
        Write-Host "  ArgoCD: $argocdStatus replicas ready" -ForegroundColor Green
    } catch {
        Write-Host "  ArgoCD: Not found or not ready" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host ""
    Write-Host "Press any key to exit and keep services running..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Run the deployment
try {
    Start-Deployment
} catch {
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Red
    Write-Error "DEPLOYMENT FAILED: $($_.Exception.Message)"
    Write-Host "=" * 80 -ForegroundColor Red
    Write-Host ""
    Write-Info "Check the error messages above and ensure all prerequisites are met."
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}