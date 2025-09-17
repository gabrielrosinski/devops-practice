# Kubernetes Monitoring Stack Health Check Script for Windows
# Service discovery and health monitoring script

#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Continuous,
    [int]$RefreshSeconds = 10,
    [switch]$ShowCommands,
    [switch]$TestConnectivity
)

$ErrorActionPreference = "SilentlyContinue"

# Color functions for output
function Write-Success { param([string]$Message) Write-Host "[+] $Message" -ForegroundColor Green }
function Write-Warning { param([string]$Message) Write-Host "[!] $Message" -ForegroundColor Yellow }
function Write-Error { param([string]$Message) Write-Host "[-] $Message" -ForegroundColor Red }
function Write-Info { param([string]$Message) Write-Host "[i] $Message" -ForegroundColor Blue }
function Write-Header { param([string]$Message) Write-Host "`n$Message" -ForegroundColor Cyan }
function Write-Separator { Write-Host "=" * 80 -ForegroundColor Gray }

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

# Function to test network connectivity
function Test-EndpointConnectivity {
    param(
        [string]$Host,
        [int]$Port,
        [int]$TimeoutMs = 5000
    )

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcpClient.BeginConnect($Host, $Port, $null, $null)
        $wait = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs, $false)

        if ($wait) {
            try {
                $tcpClient.EndConnect($asyncResult)
                $result = $true
            } catch {
                $result = $false
            }
        } else {
            $result = $false
        }

        $tcpClient.Close()
        return $result
    } catch {
        return $false
    }
}

# Function to get service information
function Get-ServiceInfo {
    param([string]$Namespace, [string]$ServiceName)

    try {
        $service = kubectl get svc $ServiceName -n $Namespace -o json | ConvertFrom-Json
        return $service
    } catch {
        return $null
    }
}

# Function to get pod information
function Get-PodInfo {
    param([string]$Namespace, [string]$LabelSelector = "")

    try {
        if ($LabelSelector) {
            $pods = kubectl get pods -n $Namespace -l $LabelSelector -o json | ConvertFrom-Json
        } else {
            $pods = kubectl get pods -n $Namespace -o json | ConvertFrom-Json
        }
        return $pods.items
    } catch {
        return @()
    }
}

# Function to check namespace status
function Get-NamespaceStatus {
    param([string]$Namespace)

    try {
        kubectl get namespace $Namespace -o json | ConvertFrom-Json | Out-Null
        return "Active"
    } catch {
        return "Not Found"
    }
}

# Function to get credentials
function Get-ServiceCredentials {
    $credentials = @{}

    # Grafana password
    try {
        $grafanaPassword = kubectl get secret --namespace monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
        $credentials.Grafana = @{
            Username = "admin"
            Password = $grafanaPassword
        }
    } catch {
        $credentials.Grafana = @{
            Username = "admin"
            Password = "Unable to retrieve"
        }
    }

    # ArgoCD password
    try {
        $argocdPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
        $credentials.ArgoCD = @{
            Username = "admin"
            Password = $argocdPassword
        }
    } catch {
        $credentials.ArgoCD = @{
            Username = "admin"
            Password = "Unable to retrieve"
        }
    }

    return $credentials
}

# Function to check deployment status
function Get-DeploymentStatus {
    param([string]$Namespace, [string]$DeploymentName)

    try {
        $deployment = kubectl get deployment $DeploymentName -n $Namespace -o json | ConvertFrom-Json
        $ready = $deployment.status.readyReplicas
        $desired = $deployment.spec.replicas

        if ($ready -eq $desired -and $ready -gt 0) {
            return "Healthy ($ready/$desired)"
        } elseif ($ready -gt 0) {
            return "Partial ($ready/$desired)"
        } else {
            return "Unhealthy (0/$desired)"
        }
    } catch {
        return "Not Found"
    }
}

# Function to display health dashboard
function Show-HealthDashboard {
    Clear-Host

    Write-Host "[*] Kubernetes Monitoring Stack Health Check" -ForegroundColor Cyan
    Write-Host "Last updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Separator

    # Check kubectl connectivity
    Write-Header "[*] Cluster Connectivity"
    try {
        kubectl cluster-info --request-timeout=10s | Out-Null
        Write-Success "Kubernetes cluster is accessible"
    } catch {
        Write-Error "Cannot connect to Kubernetes cluster"
        return
    }

    # Namespace status
    Write-Header "[*] Namespace Status"
    $namespaces = @("app", "monitoring", "argocd")
    foreach ($ns in $namespaces) {
        $status = Get-NamespaceStatus $ns
        if ($status -eq "Active") {
            Write-Success "$ns namespace: $status"
        } else {
            Write-Warning "$ns namespace: $status"
        }
    }

    # Application deployments
    Write-Header "[*] Application Status"
    $deployments = @(
        @{Namespace="app"; Name="kube-mon-demo"; Display="Demo Application"},
        @{Namespace="monitoring"; Name="prometheus-stack-kube-prom-operator"; Display="Prometheus Operator"},
        @{Namespace="monitoring"; Name="prometheus-stack-grafana"; Display="Grafana"},
        @{Namespace="argocd"; Name="argocd-server"; Display="ArgoCD Server"}
    )

    foreach ($dep in $deployments) {
        $status = Get-DeploymentStatus $dep.Namespace $dep.Name
        if ($status -like "*Healthy*") {
            Write-Success "$($dep.Display): $status"
        } elseif ($status -like "*Partial*") {
            Write-Warning "$($dep.Display): $status"
        } else {
            Write-Error "$($dep.Display): $status"
        }
    }

    # Service discovery
    Write-Header "[*] Service Discovery"
    $services = @(
        @{Namespace="app"; Name="kube-mon-demo"; Display="Demo App"; Port=80},
        @{Namespace="monitoring"; Name="prometheus-stack-kube-prom-prometheus"; Display="Prometheus"; Port=9090},
        @{Namespace="monitoring"; Name="prometheus-stack-grafana"; Display="Grafana"; Port=80},
        @{Namespace="argocd"; Name="argocd-server"; Display="ArgoCD"; Port=443}
    )

    foreach ($svc in $services) {
        $serviceInfo = Get-ServiceInfo $svc.Namespace $svc.Name
        if ($serviceInfo) {
            $clusterIP = $serviceInfo.spec.clusterIP
            $ports = $serviceInfo.spec.ports | ForEach-Object { "$($_.port):$($_.targetPort)" }
            Write-Success "$($svc.Display): $clusterIP (Ports: $($ports -join ', '))"

            # Check for external access
            if ($serviceInfo.spec.type -eq "LoadBalancer") {
                $external = $serviceInfo.status.loadBalancer.ingress
                if ($external) {
                    Write-Info "  External: $($external[0].ip):$($svc.Port)"
                }
            } elseif ($serviceInfo.spec.type -eq "NodePort") {
                $nodePort = ($serviceInfo.spec.ports | Where-Object { $_.port -eq $svc.Port }).nodePort
                Write-Info "  NodePort: <NODE_IP>:$nodePort"
            }
        } else {
            Write-Error "$($svc.Display): Service not found"
        }
    }

    # Pod health summary
    Write-Header "[*] Pod Health Summary"
    foreach ($ns in $namespaces) {
        if ((Get-NamespaceStatus $ns) -eq "Active") {
            $pods = Get-PodInfo $ns
            $running = ($pods | Where-Object { $_.status.phase -eq "Running" }).Count
            $total = $pods.Count

            if ($total -gt 0) {
                if ($running -eq $total) {
                    Write-Success "${ns}: $running/$total pods running"
                } else {
                    Write-Warning "${ns}: $running/$total pods running"
                }
            }
        }
    }

    # Connectivity tests (if requested)
    if ($TestConnectivity) {
        Write-Header "[*] Connectivity Tests"
        Write-Info "Testing localhost connectivity (requires port-forwarding)..."

        $endpoints = @(
            @{Name="Demo App"; Host="localhost"; Port=8000},
            @{Name="Prometheus"; Host="localhost"; Port=9090},
            @{Name="Grafana"; Host="localhost"; Port=3000},
            @{Name="ArgoCD"; Host="localhost"; Port=8080}
        )

        foreach ($endpoint in $endpoints) {
            if (Test-EndpointConnectivity $endpoint.Host $endpoint.Port 2000) {
                Write-Success "$($endpoint.Name): Accessible at http://$($endpoint.Host):$($endpoint.Port)"
            } else {
                Write-Warning "$($endpoint.Name): Not accessible (may need port-forwarding)"
            }
        }
    }

    # Access commands (if requested)
    if ($ShowCommands) {
        Write-Header "[*] Access Commands"
        Write-Host "Copy and paste these commands to access services:" -ForegroundColor Yellow
        Write-Host ""

        Write-Host "Demo Application:" -ForegroundColor Cyan
        Write-Host "  kubectl port-forward -n app svc/kube-mon-demo 8000:80" -ForegroundColor White
        Write-Host "  Start-Process 'http://localhost:8000'" -ForegroundColor Gray
        Write-Host ""

        Write-Host "Prometheus:" -ForegroundColor Cyan
        Write-Host "  kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090" -ForegroundColor White
        Write-Host "  Start-Process 'http://localhost:9090'" -ForegroundColor Gray
        Write-Host ""

        Write-Host "Grafana:" -ForegroundColor Cyan
        Write-Host "  kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80" -ForegroundColor White
        Write-Host "  Start-Process 'http://localhost:3000'" -ForegroundColor Gray
        Write-Host ""

        Write-Host "ArgoCD:" -ForegroundColor Cyan
        Write-Host "  kubectl port-forward svc/argocd-server -n argocd 8080:443" -ForegroundColor White
        Write-Host "  Start-Process 'https://localhost:8080'" -ForegroundColor Gray
        Write-Host ""

        # Show credentials
        $credentials = Get-ServiceCredentials

        Write-Host "[*] Service Credentials:" -ForegroundColor Yellow
        Write-Host "Grafana - Username: $($credentials.Grafana.Username), Password: $($credentials.Grafana.Password)" -ForegroundColor White
        Write-Host "ArgoCD - Username: $($credentials.ArgoCD.Username), Password: $($credentials.ArgoCD.Password)" -ForegroundColor White
    }

    Write-Separator
    if ($Continuous) {
        Write-Host "Refreshing in $RefreshSeconds seconds... (Press Ctrl+C to stop)" -ForegroundColor Gray
    } else {
        Write-Host "[!] Use -ShowCommands to see access commands, -TestConnectivity to test ports" -ForegroundColor Gray
        Write-Host "[!] Use -Continuous to run continuously, -RefreshSeconds to change refresh rate" -ForegroundColor Gray
    }
}

# Main execution
function Start-HealthCheck {
    # Check prerequisites
    if (-not (Test-CommandExists "kubectl")) {
        Write-Error "kubectl is required but not found. Please install kubectl."
        exit 1
    }

    # Single run or continuous monitoring
    if ($Continuous) {
        Write-Host "Starting continuous health monitoring..." -ForegroundColor Green
        Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow

        do {
            Show-HealthDashboard
            Start-Sleep $RefreshSeconds
        } while ($true)
    } else {
        Show-HealthDashboard
    }
}

# Display help if no parameters
if ($args.Count -eq 0 -and -not $ShowCommands -and -not $TestConnectivity -and -not $Continuous) {
    Write-Host "[*] Kubernetes Monitoring Stack Health Check" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\healthcheck.ps1                    # Single health check"
    Write-Host "  .\healthcheck.ps1 -ShowCommands      # Show access commands and credentials"
    Write-Host "  .\healthcheck.ps1 -TestConnectivity  # Test localhost connectivity"
    Write-Host "  .\healthcheck.ps1 -Continuous        # Continuous monitoring (10s refresh)"
    Write-Host "  .\healthcheck.ps1 -Continuous -RefreshSeconds 5  # Custom refresh rate"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\healthcheck.ps1 -ShowCommands -TestConnectivity"
    Write-Host "  .\healthcheck.ps1 -Continuous -RefreshSeconds 15"
    Write-Host ""
}

# Run the health check
Start-HealthCheck