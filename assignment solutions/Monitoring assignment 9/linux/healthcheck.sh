#!/bin/bash

# Kubernetes Monitoring Stack Health Check Script for Linux/macOS
# Service discovery and health monitoring script

# Default values
CONTINUOUS=false
REFRESH_SECONDS=10
SHOW_COMMANDS=false
TEST_CONNECTIVITY=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--continuous)
            CONTINUOUS=true
            shift
            ;;
        -r|--refresh)
            REFRESH_SECONDS="$2"
            shift 2
            ;;
        -s|--show-commands)
            SHOW_COMMANDS=true
            shift
            ;;
        -t|--test-connectivity)
            TEST_CONNECTIVITY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -c, --continuous         Run continuously with refresh"
            echo "  -r, --refresh SECONDS    Refresh interval (default: 10)"
            echo "  -s, --show-commands      Show access commands and credentials"
            echo "  -t, --test-connectivity  Test localhost port connectivity"
            echo "  -h, --help              Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to test network connectivity
test_endpoint_connectivity() {
    local host=$1
    local port=$2
    local timeout_val=${3:-5}

    if command_exists nc; then
        # Use netcat for connectivity test
        timeout "$timeout_val" nc -z "$host" "$port" >/dev/null 2>&1
    elif command_exists timeout && command_exists bash; then
        # Use bash TCP redirection with timeout
        timeout "$timeout_val" bash -c "exec 3<>/dev/tcp/$host/$port && exec 3<&- && exec 3>&-" >/dev/null 2>&1
    else
        # Basic check using bash TCP redirection (no timeout)
        bash -c "exec 3<>/dev/tcp/$host/$port && exec 3<&- && exec 3>&-" >/dev/null 2>&1
    fi
}

# Function to get service port
get_service_port() {
    local namespace=$1
    local service_name=$2
    kubectl get svc "$service_name" -n "$namespace" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null
}

# Function to check pods in namespace
check_pods() {
    local namespace=$1
    local label_selector=$2

    if [ -n "$label_selector" ]; then
        kubectl get pods -n "$namespace" -l "$label_selector" --no-headers 2>/dev/null
    else
        kubectl get pods -n "$namespace" --no-headers 2>/dev/null
    fi
}

# Function to count running pods
count_running_pods() {
    local namespace=$1
    local running_pods=0
    local total_pods=0

    while IFS= read -r line; do
        if [ -n "$line" ]; then
            total_pods=$((total_pods + 1))
            if echo "$line" | grep -q "Running"; then
                running_pods=$((running_pods + 1))
            fi
        fi
    done < <(check_pods "$namespace")

    echo "$running_pods/$total_pods"
}

# Function to get deployment status
get_deployment_status() {
    local namespace=$1
    local deployment_name=$2
    kubectl get deployment "$deployment_name" -n "$namespace" -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null
}

# Function to perform health check
perform_health_check() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [ "$CONTINUOUS" = true ]; then
        clear
    fi

    echo -e "${CYAN}[*] Kubernetes Monitoring Stack Health Check${NC}"
    echo -e "${GRAY}========================================================${NC}"
    echo -e "${GRAY}Timestamp: $timestamp${NC}"
    echo ""

    # Check prerequisites
    if ! command_exists kubectl; then
        echo -e "${RED}[-] kubectl not found. Please install kubectl.${NC}"
        return 1
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
        echo -e "${RED}[-] Cannot connect to Kubernetes cluster${NC}"
        return 1
    fi

    local current_context=$(kubectl config current-context 2>/dev/null)
    echo -e "${CYAN}[*] Kubernetes Context: ${current_context}${NC}"
    echo -e "${GREEN}[+] Cluster connectivity: OK${NC}"

    echo ""
    echo -e "${YELLOW}[*] Component Health Status:${NC}"
    echo "----------------------------------------"

    # Check each component
    local namespaces=("app" "monitoring" "argocd")
    local overall_health=true

    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" >/dev/null 2>&1; then
            local pod_status=$(count_running_pods "$ns")
            local running=$(echo "$pod_status" | cut -d'/' -f1)
            local total=$(echo "$pod_status" | cut -d'/' -f2)

            if [ "$total" -gt 0 ]; then
                if [ "$running" -eq "$total" ]; then
                    echo -e "${GREEN}[+] ${ns}: $running/$total pods running${NC}"
                else
                    echo -e "${YELLOW}[!] ${ns}: $running/$total pods running${NC}"
                    overall_health=false
                fi
            else
                echo -e "${RED}[-] ${ns}: No pods found${NC}"
                overall_health=false
            fi
        else
            echo -e "${RED}[-] ${ns}: Namespace not found${NC}"
            overall_health=false
        fi
    done

    echo ""
    echo -e "${YELLOW}[*] Service Status:${NC}"
    echo "----------------------------------------"

    # Check specific services
    local services=(
        "app:kube-mon-demo:Demo App"
        "monitoring:prometheus-stack-kube-prom-prometheus:Prometheus"
        "monitoring:prometheus-stack-grafana:Grafana"
        "argocd:argocd-server:ArgoCD"
    )

    for service_info in "${services[@]}"; do
        IFS=':' read -r namespace service_name display_name <<< "$service_info"

        if kubectl get svc "$service_name" -n "$namespace" >/dev/null 2>&1; then
            local port=$(get_service_port "$namespace" "$service_name")
            echo -e "${GREEN}[+] $display_name: Available (port $port)${NC}"

            if [ "$TEST_CONNECTIVITY" = true ]; then
                if test_endpoint_connectivity "localhost" "$port"; then
                    echo -e "${GREEN}    └─ Connectivity: Accessible${NC}"
                else
                    echo -e "${YELLOW}    └─ Connectivity: Requires port-forwarding${NC}"
                fi
            fi
        else
            echo -e "${RED}[-] $display_name: Not available${NC}"
            overall_health=false
        fi
    done

    if [ "$SHOW_COMMANDS" = true ]; then
        echo ""
        echo -e "${YELLOW}[*] Access Commands and Credentials:${NC}"
        echo "========================================================="

        # Demo App
        if kubectl get svc kube-mon-demo -n app >/dev/null 2>&1; then
            echo ""
            echo -e "${CYAN}[*] Demo Application:${NC}"
            echo "  Command: kubectl port-forward -n app svc/kube-mon-demo 8000:80"
            echo "  URL: http://localhost:8000"
            echo "  Endpoints:"
            echo "    - Main: http://localhost:8000/"
            echo "    - Health: http://localhost:8000/healthz"
            echo "    - Ready: http://localhost:8000/readyz"
            echo "    - Metrics: http://localhost:8000/metrics"
        fi

        # Prometheus
        if kubectl get svc prometheus-stack-kube-prom-prometheus -n monitoring >/dev/null 2>&1; then
            echo ""
            echo -e "${CYAN}[*] Prometheus:${NC}"
            echo "  Command: kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090"
            echo "  URL: http://localhost:9090"
            echo "  Authentication: None required"
        fi

        # Grafana
        if kubectl get svc prometheus-stack-grafana -n monitoring >/dev/null 2>&1; then
            echo ""
            echo -e "${CYAN}[*] Grafana:${NC}"
            echo "  Command: kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80"
            echo "  URL: http://localhost:3000"
            echo "  Username: admin"

            local grafana_password=$(kubectl get secret --namespace monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 --decode 2>/dev/null)
            if [ -n "$grafana_password" ]; then
                echo "  Password: $grafana_password"
            else
                echo "  Password: (run command below to retrieve)"
                echo "    kubectl get secret --namespace monitoring prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 --decode"
            fi
        fi

        # ArgoCD
        if kubectl get svc argocd-server -n argocd >/dev/null 2>&1; then
            echo ""
            echo -e "${CYAN}[*] ArgoCD:${NC}"
            echo "  Command: kubectl port-forward -n argocd svc/argocd-server 8080:443"
            echo "  URL: https://localhost:8080"
            echo "  Username: admin"

            local argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 --decode 2>/dev/null)
            if [ -n "$argocd_password" ]; then
                echo "  Password: $argocd_password"
            else
                echo "  Password: (run command below to retrieve)"
                echo "    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode"
            fi
            echo "  Note: Accept SSL certificate warning in browser"
        fi
    fi

    echo ""
    if [ "$overall_health" = true ]; then
        echo -e "${GREEN}[+] Overall Health: All components healthy${NC}"
    else
        echo -e "${YELLOW}[!] Overall Health: Some issues detected${NC}"
    fi

    if [ "$CONTINUOUS" = false ]; then
        echo ""
        echo -e "${YELLOW}[*] Usage Examples:${NC}"
        echo "  linux/healthcheck.sh                    # Single health check"
        echo "  linux/healthcheck.sh --show-commands    # Show access commands and credentials"
        echo "  linux/healthcheck.sh --test-connectivity # Test localhost connectivity"
        echo "  linux/healthcheck.sh --continuous       # Continuous monitoring (10s refresh)"
        echo "  linux/healthcheck.sh --continuous --refresh 5  # Custom refresh rate"
        echo ""
        echo "  Combined options:"
        echo "  linux/healthcheck.sh --show-commands --test-connectivity"
        echo "  linux/healthcheck.sh --continuous --refresh 15"
    fi
}

# Main execution
if [ "$CONTINUOUS" = true ]; then
    echo -e "${CYAN}[*] Starting continuous health monitoring (refresh: ${REFRESH_SECONDS}s)${NC}"
    echo -e "${GRAY}Press Ctrl+C to stop${NC}"
    echo ""

    while true; do
        perform_health_check
        sleep "$REFRESH_SECONDS"
    done
else
    perform_health_check
fi