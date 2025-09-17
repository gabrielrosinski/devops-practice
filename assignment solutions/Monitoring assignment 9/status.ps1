# Quick Deployment Status Check Script for Windows
# Shows current status of Kubernetes monitoring stack

#Requires -Version 5.1

Write-Host "🔍 Kubernetes Monitoring Stack Status Check" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host ""

# Check if kubectl is available
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "❌ kubectl not found. Please install kubectl." -ForegroundColor Red
    exit 1
}

# Get current context
try {
    $currentContext = kubectl config current-context 2>$null
    Write-Host "📋 Kubernetes Context: $currentContext" -ForegroundColor Cyan
} catch {
    Write-Host "❌ No Kubernetes context available" -ForegroundColor Red
    exit 1
}

# Test connectivity
try {
    kubectl cluster-info --request-timeout=5s | Out-Null
    Write-Host "✅ Cluster connectivity: OK" -ForegroundColor Green
} catch {
    Write-Host "❌ Cannot connect to Kubernetes cluster" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🚀 Component Status:" -ForegroundColor Yellow
Write-Host "-" * 40 -ForegroundColor Gray

# Check Demo App
try {
    $demoApp = kubectl get deployment kube-mon-demo -n app -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>$null
    if ($demoApp) {
        Write-Host "  Demo App (kube-mon-demo): $demoApp replicas ready" -ForegroundColor Green
    } else {
        Write-Host "  Demo App: Not deployed" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Demo App: Not found" -ForegroundColor Red
}

# Check Prometheus
try {
    $prometheus = kubectl get statefulset prometheus-prometheus-stack-kube-prom-prometheus -n monitoring -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>$null
    if ($prometheus) {
        Write-Host "  Prometheus: $prometheus replicas ready" -ForegroundColor Green
    } else {
        Write-Host "  Prometheus: Not ready" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Prometheus: Not found" -ForegroundColor Red
}

# Check Grafana
try {
    $grafana = kubectl get deployment prometheus-stack-grafana -n monitoring -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>$null
    if ($grafana) {
        Write-Host "  Grafana: $grafana replicas ready" -ForegroundColor Green
    } else {
        Write-Host "  Grafana: Not ready" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Grafana: Not found" -ForegroundColor Red
}

# Check ArgoCD
try {
    $argocd = kubectl get deployment argocd-server -n argocd -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>$null
    if ($argocd) {
        Write-Host "  ArgoCD: $argocd replicas ready" -ForegroundColor Green
    } else {
        Write-Host "  ArgoCD: Not ready" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ArgoCD: Not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "🌐 Service Access Information:" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Gray

# Demo App
Write-Host ""
Write-Host "📱 Demo Application:" -ForegroundColor Cyan
try {
    $demoSvc = kubectl get svc kube-mon-demo -n app -o name 2>$null
    if ($demoSvc) {
        Write-Host "  ✅ Status: Available" -ForegroundColor Green
        Write-Host "  🔗 Command: kubectl port-forward -n app svc/kube-mon-demo 8000:80" -ForegroundColor White
        Write-Host "  🌐 URL: http://localhost:8000" -ForegroundColor White
        Write-Host "  📋 Endpoints:" -ForegroundColor Gray
        Write-Host "     • Main: http://localhost:8000/" -ForegroundColor Gray
        Write-Host "     • Health: http://localhost:8000/healthz" -ForegroundColor Gray
        Write-Host "     • Ready: http://localhost:8000/readyz" -ForegroundColor Gray
        Write-Host "     • Metrics: http://localhost:8000/metrics" -ForegroundColor Gray
    } else {
        Write-Host "  ❌ Status: Not deployed" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ Status: Not found" -ForegroundColor Red
}

# Prometheus
Write-Host ""
Write-Host "📊 Prometheus:" -ForegroundColor Cyan
try {
    $promSvc = kubectl get svc prometheus-stack-kube-prom-prometheus -n monitoring -o name 2>$null
    if ($promSvc) {
        Write-Host "  ✅ Status: Available" -ForegroundColor Green
        Write-Host "  🔗 Command: kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090" -ForegroundColor White
        Write-Host "  🌐 URL: http://localhost:9090" -ForegroundColor White
        Write-Host "  🔐 Authentication: None required" -ForegroundColor Gray
    } else {
        Write-Host "  ❌ Status: Not deployed" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ Status: Not found" -ForegroundColor Red
}

# Grafana
Write-Host ""
Write-Host "📈 Grafana:" -ForegroundColor Cyan
try {
    $grafanaSvc = kubectl get svc prometheus-stack-grafana -n monitoring -o name 2>$null
    if ($grafanaSvc) {
        Write-Host "  ✅ Status: Available" -ForegroundColor Green
        Write-Host "  🔗 Command: kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80" -ForegroundColor White
        Write-Host "  🌐 URL: http://localhost:3000" -ForegroundColor White
        Write-Host "  👤 Username: admin" -ForegroundColor Yellow

        # Get Grafana password
        try {
            $grafanaPassword = kubectl get secret --namespace monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-password}" 2>$null | ForEach-Object {
                [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))
            }
            if ($grafanaPassword) {
                Write-Host "  🔑 Password: $grafanaPassword" -ForegroundColor Yellow
            } else {
                Write-Host "  🔑 Password: (run command below to retrieve)" -ForegroundColor Yellow
                Write-Host "     kubectl get secret --namespace monitoring prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 --decode" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  🔑 Password: (secret not found - Grafana may not be ready)" -ForegroundColor Red
        }

        Write-Host "  📋 Important: Import grafana-dashboard.json manually" -ForegroundColor Gray
        Write-Host "     1. Go to Dashboards → Import" -ForegroundColor Gray
        Write-Host "     2. Upload grafana-dashboard.json from project directory" -ForegroundColor Gray
    } else {
        Write-Host "  ❌ Status: Not deployed" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ Status: Not found" -ForegroundColor Red
}

# ArgoCD
Write-Host ""
Write-Host "🚀 ArgoCD:" -ForegroundColor Cyan
try {
    $argoSvc = kubectl get svc argocd-server -n argocd -o name 2>$null
    if ($argoSvc) {
        Write-Host "  ✅ Status: Available" -ForegroundColor Green
        Write-Host "  🔗 Command: kubectl port-forward -n argocd svc/argocd-server 8080:443" -ForegroundColor White
        Write-Host "  🌐 URL: https://localhost:8080" -ForegroundColor White
        Write-Host "  👤 Username: admin" -ForegroundColor Yellow

        # Get ArgoCD password
        try {
            $argocdPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>$null | ForEach-Object {
                [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))
            }
            if ($argocdPassword) {
                Write-Host "  🔑 Password: $argocdPassword" -ForegroundColor Yellow
            } else {
                Write-Host "  🔑 Password: (run command below to retrieve)" -ForegroundColor Yellow
                Write-Host "     kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  🔑 Password: (secret not found - ArgoCD may not be ready)" -ForegroundColor Red
        }

        Write-Host "  ⚠️  Note: Accept SSL certificate warning in browser" -ForegroundColor Gray
    } else {
        Write-Host "  ❌ Status: Not deployed" -ForegroundColor Red
    }
} catch {
    Write-Host "  ❌ Status: Not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "🚀 Quick Launch Commands:" -ForegroundColor Yellow
Write-Host "-" * 40 -ForegroundColor Gray

# Check if any services are available for quick launch
$availableServices = @()

try {
    if (kubectl get svc kube-mon-demo -n app -o name 2>$null) {
        $availableServices += @{Name="Demo App"; Port="8000"; Command="kubectl port-forward -n app svc/kube-mon-demo 8000:80"}
    }
} catch {}

try {
    if (kubectl get svc prometheus-stack-kube-prom-prometheus -n monitoring -o name 2>$null) {
        $availableServices += @{Name="Prometheus"; Port="9090"; Command="kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090"}
    }
} catch {}

try {
    if (kubectl get svc prometheus-stack-grafana -n monitoring -o name 2>$null) {
        $availableServices += @{Name="Grafana"; Port="3000"; Command="kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80"}
    }
} catch {}

try {
    if (kubectl get svc argocd-server -n argocd -o name 2>$null) {
        $availableServices += @{Name="ArgoCD"; Port="8080"; Command="kubectl port-forward -n argocd svc/argocd-server 8080:443"}
    }
} catch {}

if ($availableServices.Count -gt 0) {
    Write-Host "  Copy and paste these commands in separate PowerShell windows:" -ForegroundColor Gray
    Write-Host ""
    foreach ($svc in $availableServices) {
        Write-Host "  # $($svc.Name)" -ForegroundColor Cyan
        Write-Host "  $($svc.Command)" -ForegroundColor White
        Write-Host ""
    }
    Write-Host "  Then access services at:" -ForegroundColor Gray
    foreach ($svc in $availableServices) {
        if ($svc.Name -eq "ArgoCD") {
            Write-Host "  • $($svc.Name): https://localhost:$($svc.Port)" -ForegroundColor White
        } else {
            Write-Host "  • $($svc.Name): http://localhost:$($svc.Port)" -ForegroundColor White
        }
    }
} else {
    Write-Host "  No services currently deployed. Run .\deploy.ps1 to deploy the stack." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "💡 Additional Tools:" -ForegroundColor Yellow
Write-Host "  - .\healthcheck.ps1     # Detailed real-time monitoring" -ForegroundColor Gray
Write-Host "  - .\deploy.ps1          # Deploy missing components" -ForegroundColor Gray
Write-Host "  - .\cleanup.ps1         # Remove all components" -ForegroundColor Gray
Write-Host "  - .\status.ps1          # This status check (run anytime)" -ForegroundColor Gray
Write-Host ""