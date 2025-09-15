#!/bin/bash

set -e  # Exit on any error

echo "🧹 Starting Kubernetes Monitoring Stack Cleanup"
echo "==============================================="
echo ""
echo "This script cleans up resources deployed by deploy.sh"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if namespace exists
namespace_exists() {
    kubectl get namespace "$1" >/dev/null 2>&1
}

# Function to check if helm release exists
helm_release_exists() {
    local namespace=$1
    local release=$2
    helm list -n "$namespace" | grep -q "$release" 2>/dev/null
}

echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"

# Check kubectl
if ! command_exists kubectl; then
    echo -e "${RED}❌ kubectl is not installed. Cannot proceed with cleanup.${NC}"
    exit 1
fi

# Check Helm
if ! command_exists helm; then
    echo -e "${YELLOW}⚠️  Helm not found. Some cleanup operations may be skipped.${NC}"
fi

# Test kubectl connectivity
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster. Please ensure your cluster is running.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

echo -e "${YELLOW}Step 2: Cleaning up demo application...${NC}"

# Check if app namespace exists
if namespace_exists "app"; then
    echo -e "${BLUE}Deleting demo application resources...${NC}"

    # Delete ServiceMonitor first
    if kubectl get servicemonitor kube-mon-demo -n app >/dev/null 2>&1; then
        echo -e "${BLUE}Deleting ServiceMonitor...${NC}"
        kubectl delete servicemonitor kube-mon-demo -n app || true
    fi

    # Delete service
    if kubectl get service kube-mon-demo -n app >/dev/null 2>&1; then
        echo -e "${BLUE}Deleting demo app service...${NC}"
        kubectl delete service kube-mon-demo -n app || true
    fi

    # Delete deployment
    if kubectl get deployment kube-mon-demo -n app >/dev/null 2>&1; then
        echo -e "${BLUE}Deleting demo app deployment...${NC}"
        kubectl delete deployment kube-mon-demo -n app || true
    fi

    # Wait for pods to terminate
    echo -e "${BLUE}Waiting for pods to terminate...${NC}"
    kubectl wait --for=delete pods -l app=kube-mon-demo -n app --timeout=60s || true

    # Delete app namespace
    echo -e "${BLUE}Deleting app namespace...${NC}"
    kubectl delete namespace app || true

    echo -e "${GREEN}✅ Demo application resources cleaned up${NC}"
else
    echo -e "${YELLOW}⚠️  App namespace not found, skipping demo app cleanup${NC}"
fi

echo -e "${YELLOW}Step 3: Cleaning up Prometheus alerts...${NC}"

# Delete PrometheusRule for alerts
if kubectl get prometheusrule python-app-alerts -n monitoring >/dev/null 2>&1; then
    echo -e "${BLUE}Deleting Prometheus alert rules...${NC}"
    kubectl delete prometheusrule python-app-alerts -n monitoring || true
else
    echo -e "${YELLOW}⚠️  Prometheus alert rules not found${NC}"
fi

echo -e "${YELLOW}Step 4: Cleaning up Prometheus Stack...${NC}"

# Check if monitoring namespace exists and if Helm release exists
if namespace_exists "monitoring" && command_exists helm; then
    if helm_release_exists "monitoring" "prometheus-stack"; then
        echo -e "${BLUE}Uninstalling Prometheus stack...${NC}"
        helm uninstall prometheus-stack -n monitoring

        # Wait for pods to terminate
        echo -e "${BLUE}Waiting for monitoring pods to terminate...${NC}"
        kubectl wait --for=delete pods --all -n monitoring --timeout=120s || true

        echo -e "${GREEN}✅ Prometheus stack uninstalled${NC}"
    else
        echo -e "${YELLOW}⚠️  Prometheus stack Helm release not found${NC}"
    fi

    # Delete any remaining resources in monitoring namespace
    echo -e "${BLUE}Cleaning up any remaining monitoring resources...${NC}"
    kubectl delete all --all -n monitoring || true
    kubectl delete pvc --all -n monitoring || true
    kubectl delete secrets --all -n monitoring || true
    kubectl delete configmaps --all -n monitoring || true

    # Delete monitoring namespace
    echo -e "${BLUE}Deleting monitoring namespace...${NC}"
    kubectl delete namespace monitoring || true

    echo -e "${GREEN}✅ Monitoring namespace cleaned up${NC}"
else
    if ! namespace_exists "monitoring"; then
        echo -e "${YELLOW}⚠️  Monitoring namespace not found, skipping monitoring cleanup${NC}"
    fi
    if ! command_exists helm; then
        echo -e "${YELLOW}⚠️  Helm not found, manually cleaning monitoring namespace${NC}"
        if namespace_exists "monitoring"; then
            kubectl delete namespace monitoring || true
        fi
    fi
fi

echo -e "${YELLOW}Step 5: Cleaning up ArgoCD...${NC}"

# Check if ArgoCD namespace exists
if namespace_exists "argocd"; then
    echo -e "${BLUE}Cleaning up ArgoCD resources...${NC}"

    # Delete ArgoCD Application
    if kubectl get application python-monitoring-app -n argocd >/dev/null 2>&1; then
        echo -e "${BLUE}Deleting ArgoCD Application...${NC}"
        kubectl delete application python-monitoring-app -n argocd || true
    fi

    # Delete all ArgoCD resources
    echo -e "${BLUE}Deleting all ArgoCD resources...${NC}"
    kubectl delete all --all -n argocd || true
    kubectl delete pvc --all -n argocd || true
    kubectl delete secrets --all -n argocd || true
    kubectl delete configmaps --all -n argocd || true

    # Wait for pods to terminate
    echo -e "${BLUE}Waiting for ArgoCD pods to terminate...${NC}"
    kubectl wait --for=delete pods --all -n argocd --timeout=120s || true

    # Delete ArgoCD namespace
    echo -e "${BLUE}Deleting argocd namespace...${NC}"
    kubectl delete namespace argocd || true

    echo -e "${GREEN}✅ ArgoCD resources cleaned up${NC}"
else
    echo -e "${YELLOW}⚠️  ArgoCD namespace not found, skipping ArgoCD cleanup${NC}"
fi

echo -e "${YELLOW}Step 6: Cleaning up Docker images...${NC}"

# Check if Docker is available
if command_exists docker && docker info >/dev/null 2>&1; then
    IMAGE_NAME="your-dockerhub/kube-mon-demo:0.1"

    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${IMAGE_NAME}$"; then
        echo -e "${BLUE}Removing Docker image: $IMAGE_NAME${NC}"
        docker rmi $IMAGE_NAME || true
        echo -e "${GREEN}✅ Docker image removed${NC}"
    else
        echo -e "${YELLOW}⚠️  Docker image $IMAGE_NAME not found${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Docker not available, skipping image cleanup${NC}"
fi

echo -e "${YELLOW}Step 7: Cleaning up minikube (optional)...${NC}"

# Check if minikube exists and is running
if command_exists minikube; then
    status=$(minikube status --format="{{.Host}}" 2>/dev/null || echo "Stopped")
    if [ "$status" = "Running" ]; then
        read -p "$(echo -e ${BLUE}Minikube is running. Do you want to stop it? [y/N]:${NC} )" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Stopping minikube...${NC}"
            minikube stop
            echo -e "${GREEN}✅ Minikube stopped${NC}"
        else
            echo -e "${YELLOW}⚠️  Minikube left running${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Minikube is not running${NC}"
    fi

    # Ask if user wants to delete minikube cluster entirely
    read -p "$(echo -e ${BLUE}Do you want to completely delete the minikube cluster? [y/N]:${NC} )" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Deleting minikube cluster...${NC}"
        minikube delete
        echo -e "${GREEN}✅ Minikube cluster deleted${NC}"
    else
        echo -e "${YELLOW}⚠️  Minikube cluster preserved${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Minikube not found, skipping minikube cleanup${NC}"
fi

echo -e "${YELLOW}Step 8: Final verification...${NC}"

# Check for any remaining resources
echo -e "${BLUE}Checking for remaining resources...${NC}"

remaining_namespaces=""
if namespace_exists "app"; then
    remaining_namespaces="$remaining_namespaces app"
fi
if namespace_exists "monitoring"; then
    remaining_namespaces="$remaining_namespaces monitoring"
fi
if namespace_exists "argocd"; then
    remaining_namespaces="$remaining_namespaces argocd"
fi

if [ -n "$remaining_namespaces" ]; then
    echo -e "${YELLOW}⚠️  Some namespaces still exist: $remaining_namespaces${NC}"
    echo -e "${BLUE}This might be normal if they're in 'Terminating' state${NC}"
else
    echo -e "${GREEN}✅ All target namespaces have been removed${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Cleanup completed!${NC}"
echo "==================="
echo ""
echo -e "${YELLOW}Note:${NC} To redeploy the monitoring stack, run: ./deploy.sh"
echo -e "${YELLOW}Note:${NC} If you see namespaces in 'Terminating' state, this is normal."
echo ""
echo -e "${GREEN}✅ Your cluster is now clean!${NC}"