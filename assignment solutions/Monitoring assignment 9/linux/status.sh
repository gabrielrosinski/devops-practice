#!/bin/bash

# Quick Deployment Status Check Script for Linux/macOS
# Shows current status of Kubernetes monitoring stack

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo -e "${CYAN}[*] Kubernetes Monitoring Stack Status Check${NC}"
echo "============================================================"
echo ""

# Check if kubectl is available
if ! command -v kubectl >/dev/null 2>&1; then
    echo -e "${RED}[-] kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

# Get current context
if ! current_context=$(kubectl config current-context 2>/dev/null); then
    echo -e "${RED}[-] No Kubernetes context available${NC}"
    exit 1
fi
echo -e "${CYAN}[*] Kubernetes Context: ${current_context}${NC}"

# Test connectivity
if ! kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
    echo -e "${RED}[-] Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi
echo -e "${GREEN}[+] Cluster connectivity: OK${NC}"

echo ""
echo -e "${YELLOW}[*] Component Status:${NC}"
echo "----------------------------------------"

# Check Demo App
demo_app=$(kubectl get deployment kube-mon-demo -n app -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null)
if [ -n "$demo_app" ]; then
    echo -e "${GREEN}  Demo App (kube-mon-demo): $demo_app replicas ready${NC}"
else
    if kubectl get namespace app >/dev/null 2>&1; then
        echo -e "${YELLOW}  Demo App: Not deployed${NC}"
    else
        echo -e "${RED}  Demo App: Not found${NC}"
    fi
fi

# Check Prometheus
prometheus_app=$(kubectl get statefulset prometheus-prometheus-stack-kube-prom-prometheus -n monitoring -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null)
if [ -n "$prometheus_app" ]; then
    echo -e "${GREEN}  Prometheus: $prometheus_app replicas ready${NC}"
else
    if kubectl get namespace monitoring >/dev/null 2>&1; then
        echo -e "${YELLOW}  Prometheus: Not ready${NC}"
    else
        echo -e "${RED}  Prometheus: Not found${NC}"
    fi
fi

# Check Grafana
grafana_app=$(kubectl get deployment prometheus-stack-grafana -n monitoring -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null)
if [ -n "$grafana_app" ]; then
    echo -e "${GREEN}  Grafana: $grafana_app replicas ready${NC}"
else
    if kubectl get namespace monitoring >/dev/null 2>&1; then
        echo -e "${YELLOW}  Grafana: Not ready${NC}"
    else
        echo -e "${RED}  Grafana: Not found${NC}"
    fi
fi

# Check ArgoCD
argocd_app=$(kubectl get deployment argocd-server -n argocd -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null)
if [ -n "$argocd_app" ]; then
    echo -e "${GREEN}  ArgoCD: $argocd_app replicas ready${NC}"
else
    if kubectl get namespace argocd >/dev/null 2>&1; then
        echo -e "${YELLOW}  ArgoCD: Not ready${NC}"
    else
        echo -e "${RED}  ArgoCD: Not found${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}[*] Service Access Information:${NC}"
echo "============================================================"

# Demo App
echo ""
echo -e "${CYAN}[*] Demo Application:${NC}"
if kubectl get svc kube-mon-demo -n app >/dev/null 2>&1; then
    echo -e "${GREEN}  [+] Status: Available${NC}"
    echo -e "  [*] Command: kubectl port-forward -n app svc/kube-mon-demo 8000:80"
    echo -e "  [*] URL: http://localhost:8000"
    echo -e "${GRAY}  [*] Endpoints:${NC}"
    echo -e "${GRAY}     - Main: http://localhost:8000/${NC}"
    echo -e "${GRAY}     - Health: http://localhost:8000/healthz${NC}"
    echo -e "${GRAY}     - Ready: http://localhost:8000/readyz${NC}"
    echo -e "${GRAY}     - Metrics: http://localhost:8000/metrics${NC}"
else
    echo -e "${RED}  [-] Status: Not deployed${NC}"
fi

# Prometheus
echo ""
echo -e "${CYAN}[*] Prometheus:${NC}"
if kubectl get svc prometheus-stack-kube-prom-prometheus -n monitoring >/dev/null 2>&1; then
    echo -e "${GREEN}  [+] Status: Available${NC}"
    echo -e "  [*] Command: kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090"
    echo -e "  [*] URL: http://localhost:9090"
    echo -e "${GRAY}  [*] Authentication: None required${NC}"
else
    echo -e "${RED}  [-] Status: Not deployed${NC}"
fi

# Grafana
echo ""
echo -e "${CYAN}[*] Grafana:${NC}"
if kubectl get svc prometheus-stack-grafana -n monitoring >/dev/null 2>&1; then
    echo -e "${GREEN}  [+] Status: Available${NC}"
    echo -e "  [*] Command: kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80"
    echo -e "  [*] URL: http://localhost:3000"
    echo -e "${YELLOW}  [*] Username: admin${NC}"

    # Get Grafana password
    grafana_password=$(kubectl get secret --namespace monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 --decode 2>/dev/null)
    if [ -n "$grafana_password" ]; then
        echo -e "${YELLOW}  [*] Password: $grafana_password${NC}"
    else
        echo -e "${YELLOW}  [*] Password: (run command below to retrieve)${NC}"
        echo -e "${GRAY}     kubectl get secret --namespace monitoring prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 --decode${NC}"
    fi

    echo -e "${GRAY}  [!] Important: Import grafana-dashboard.json manually${NC}"
    echo -e "${GRAY}     1. Go to Dashboards -> Import${NC}"
    echo -e "${GRAY}     2. Upload grafana-dashboard.json from project directory${NC}"
else
    echo -e "${RED}  [-] Status: Not deployed${NC}"
fi

# ArgoCD
echo ""
echo -e "${CYAN}[*] ArgoCD:${NC}"
if kubectl get svc argocd-server -n argocd >/dev/null 2>&1; then
    echo -e "${GREEN}  [+] Status: Available${NC}"
    echo -e "  [*] Command: kubectl port-forward -n argocd svc/argocd-server 8080:443"
    echo -e "  [*] URL: https://localhost:8080"
    echo -e "${YELLOW}  [*] Username: admin${NC}"

    # Get ArgoCD password
    argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 --decode 2>/dev/null)
    if [ -n "$argocd_password" ]; then
        echo -e "${YELLOW}  [*] Password: $argocd_password${NC}"
    else
        echo -e "${YELLOW}  [*] Password: (run command below to retrieve)${NC}"
        echo -e "${GRAY}     kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode${NC}"
    fi

    echo -e "${GRAY}  [!] Note: Accept SSL certificate warning in browser${NC}"
else
    echo -e "${RED}  [-] Status: Not deployed${NC}"
fi

echo ""
echo -e "${YELLOW}[*] Quick Launch Commands:${NC}"
echo "----------------------------------------"

# Check if any services are available for quick launch
available_services=()

if kubectl get svc kube-mon-demo -n app >/dev/null 2>&1; then
    available_services+=("Demo App:8000:kubectl port-forward -n app svc/kube-mon-demo 8000:80")
fi

if kubectl get svc prometheus-stack-kube-prom-prometheus -n monitoring >/dev/null 2>&1; then
    available_services+=("Prometheus:9090:kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090")
fi

if kubectl get svc prometheus-stack-grafana -n monitoring >/dev/null 2>&1; then
    available_services+=("Grafana:3000:kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80")
fi

if kubectl get svc argocd-server -n argocd >/dev/null 2>&1; then
    available_services+=("ArgoCD:8080:kubectl port-forward -n argocd svc/argocd-server 8080:443")
fi

if [ ${#available_services[@]} -gt 0 ]; then
    echo -e "${GRAY}  Copy and paste these commands in separate terminal windows:${NC}"
    echo ""
    for service in "${available_services[@]}"; do
        IFS=':' read -r name port command <<< "$service"
        echo -e "${CYAN}  # $name${NC}"
        echo "  $command"
        echo ""
    done
    echo -e "${GRAY}  Then access services at:${NC}"
    for service in "${available_services[@]}"; do
        IFS=':' read -r name port command <<< "$service"
        if [ "$name" = "ArgoCD" ]; then
            echo "  - $name: https://localhost:$port"
        else
            echo "  - $name: http://localhost:$port"
        fi
    done
else
    echo -e "${YELLOW}  No services currently deployed. Run linux/deploy.sh to deploy the stack.${NC}"
fi

echo ""
echo -e "${YELLOW}[*] Additional Tools:${NC}"
echo -e "${GRAY}  - linux/healthcheck.sh     # Detailed real-time monitoring${NC}"
echo -e "${GRAY}  - linux/deploy.sh          # Deploy missing components${NC}"
echo -e "${GRAY}  - linux/cleanup.sh         # Remove all components${NC}"
echo -e "${GRAY}  - linux/status.sh          # This status check (run anytime)${NC}"
echo ""