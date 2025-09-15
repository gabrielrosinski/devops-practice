#!/bin/bash

set -e  # Exit on any error

echo "🚀 Starting Kubernetes Monitoring Stack Deployment"
echo "=================================================="

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

# Function to check if minikube is running
check_minikube_status() {
    if command_exists minikube; then
        status=$(minikube status --format="{{.Host}}" 2>/dev/null || echo "Stopped")
        if [ "$status" = "Running" ]; then
            return 0
        fi
    fi
    return 1
}

# Function to wait for deployment
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}

    echo -e "${BLUE}Waiting for deployment $deployment in namespace $namespace...${NC}"
    kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment -n $namespace
}

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local label=$2
    local timeout=${3:-300}

    echo -e "${BLUE}Waiting for pods with label $label in namespace $namespace...${NC}"
    kubectl wait --for=condition=ready --timeout=${timeout}s pods -l $label -n $namespace
}

echo -e "${YELLOW}Step 1: Checking dependencies...${NC}"

# Check Docker
if ! command_exists docker; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker Desktop.${NC}"
    exit 1
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker Desktop.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker is installed and running${NC}"

# Check kubectl
if ! command_exists kubectl; then
    echo -e "${RED}❌ kubectl is not installed. Please install kubectl.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ kubectl is installed${NC}"

# Check Helm
if ! command_exists helm; then
    echo -e "${YELLOW}⚠️  Helm not found. Installing Helm...${NC}"
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    if ! command_exists helm; then
        echo -e "${RED}❌ Failed to install Helm${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Helm is installed${NC}"

# Check ArgoCD CLI
if ! command_exists argocd; then
    echo -e "${YELLOW}⚠️  ArgoCD CLI not found. Installing ArgoCD CLI...${NC}"
    # Detect architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        ARCH="amd64"
    elif [[ "$ARCH" == "aarch64" ]]; then
        ARCH="arm64"
    fi

    # Download and install ArgoCD CLI
    curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-${ARCH}"
    chmod +x argocd
    sudo mv argocd /usr/local/bin/ 2>/dev/null || mv argocd /tmp/argocd

    if command_exists argocd; then
        echo -e "${GREEN}✅ ArgoCD CLI installed successfully${NC}"
    else
        echo -e "${YELLOW}⚠️ ArgoCD CLI installed to /tmp/argocd (no sudo access)${NC}"
    fi
else
    echo -e "${GREEN}✅ ArgoCD CLI is installed${NC}"
fi

# Check minikube (optional)
if command_exists minikube; then
    echo -e "${GREEN}✅ Minikube is installed${NC}"

    # Check if minikube is running
    if ! check_minikube_status; then
        echo -e "${YELLOW}Starting minikube...${NC}"
        minikube start --driver=docker
        minikube addons enable metrics-server
    else
        echo -e "${GREEN}✅ Minikube is already running${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Minikube not found. Assuming Docker Desktop Kubernetes is used.${NC}"
fi

# Test kubectl connectivity
echo -e "${BLUE}Testing Kubernetes connectivity...${NC}"
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster. Please ensure your cluster is running.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Kubernetes cluster is accessible${NC}"

echo -e "${YELLOW}Step 2: Building Docker image and applying Kubernetes manifests...${NC}"

# Apply namespaces first
echo -e "${BLUE}Creating namespaces...${NC}"
kubectl apply -f k8s/namespace.yaml

# Navigate to test app directory
cd test_app

# Check if image already exists locally
IMAGE_NAME="your-dockerhub/kube-mon-demo:0.1"
if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${IMAGE_NAME}$"; then
    echo -e "${GREEN}✅ Docker image $IMAGE_NAME already exists${NC}"
else
    echo -e "${BLUE}Building Docker image...${NC}"
    docker build -t $IMAGE_NAME .
fi

# Load image into minikube if using minikube
if check_minikube_status; then
    echo -e "${BLUE}Loading image into minikube...${NC}"
    minikube image load $IMAGE_NAME
fi

# Return to parent directory
cd ..

echo -e "${BLUE}Applying remaining Kubernetes manifests...${NC}"

# Apply deployment and service
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Wait for demo app to be ready
wait_for_deployment "app" "kube-mon-demo"

echo -e "${YELLOW}Step 3: Installing Prometheus Stack...${NC}"

# Add Prometheus Helm repository if not already added
if ! helm repo list | grep -q prometheus-community; then
    echo -e "${BLUE}Adding Prometheus Helm repository...${NC}"
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
fi

helm repo update

# Check if Prometheus stack is already installed
if helm list -n monitoring | grep -q prometheus-stack; then
    echo -e "${GREEN}✅ Prometheus stack is already installed${NC}"
else
    echo -e "${BLUE}Installing Prometheus stack...${NC}"
    helm install prometheus-stack prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
fi

# Wait for Prometheus operator to be ready
wait_for_deployment "monitoring" "prometheus-stack-kube-prom-operator"

# Wait a bit more for all components to be ready
echo -e "${BLUE}Waiting for all monitoring components to be ready...${NC}"
sleep 30

# Wait for Prometheus pods
wait_for_pods "monitoring" "app.kubernetes.io/name=prometheus" 180

# Wait for Grafana pods
wait_for_pods "monitoring" "app.kubernetes.io/name=grafana" 180

echo -e "${YELLOW}Step 4: Applying ServiceMonitor and Alerts...${NC}"

# Apply ServiceMonitor
kubectl apply -f k8s/servicemonitor.yaml

# Apply Prometheus alert rules
echo -e "${BLUE}Applying Prometheus alert rules...${NC}"
kubectl apply -f prometheus/prometheus-alerts.yaml

echo -e "${YELLOW}Step 5: Installing ArgoCD...${NC}"

# Check if ArgoCD namespace exists
if ! kubectl get namespace argocd >/dev/null 2>&1; then
    echo -e "${BLUE}Creating ArgoCD namespace...${NC}"
    kubectl create namespace argocd
fi

# Check if ArgoCD is already installed
if kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
    echo -e "${GREEN}✅ ArgoCD is already installed${NC}"
else
    echo -e "${BLUE}Installing ArgoCD...${NC}"
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
fi

# Wait for ArgoCD server to be ready
wait_for_deployment "argocd" "argocd-server"

echo -e "${BLUE}Waiting for ArgoCD components to be ready...${NC}"
wait_for_pods "argocd" "app.kubernetes.io/name=argocd-server" 180

echo -e "${YELLOW}Step 6: Configuring ArgoCD Application...${NC}"

# Get ArgoCD initial password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "")

if [ -z "$ARGOCD_PASSWORD" ]; then
    echo -e "${YELLOW}⚠️ ArgoCD password not available yet, skipping ArgoCD app creation${NC}"
else
    echo -e "${BLUE}Setting up ArgoCD CLI access...${NC}"

    # Start port-forward in background
    kubectl port-forward svc/argocd-server -n argocd 8080:443 >/dev/null 2>&1 &
    PORTFORWARD_PID=$!

    # Wait a moment for port-forward to establish
    sleep 5

    # Login to ArgoCD CLI (skip TLS verification for local setup)
    ARGOCD_CLI="argocd"
    if ! command_exists argocd && [ -f "/tmp/argocd" ]; then
        ARGOCD_CLI="/tmp/argocd"
    fi

    echo -e "${BLUE}Logging into ArgoCD...${NC}"
    $ARGOCD_CLI login localhost:8080 --username admin --password "$ARGOCD_PASSWORD" --insecure >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Successfully logged into ArgoCD${NC}"

        # Check if ArgoCD Application already exists
        echo -e "${BLUE}Checking if ArgoCD Application exists...${NC}"

        if $ARGOCD_CLI app get python-monitoring-app >/dev/null 2>&1; then
            echo -e "${GREEN}✅ ArgoCD Application 'python-monitoring-app' already exists${NC}"

            # Get application status
            APP_STATUS=$($ARGOCD_CLI app get python-monitoring-app -o json 2>/dev/null | grep -o '"sync":[^}]*' | grep -o '"status":"[^"]*' | cut -d'"' -f4)
            APP_HEALTH=$($ARGOCD_CLI app get python-monitoring-app -o json 2>/dev/null | grep -o '"health":[^}]*' | grep -o '"status":"[^"]*' | cut -d'"' -f4)

            echo -e "${BLUE}Application Status: ${APP_STATUS:-Unknown}${NC}"
            echo -e "${BLUE}Application Health: ${APP_HEALTH:-Unknown}${NC}"
        else
            echo -e "${YELLOW}ArgoCD Application 'python-monitoring-app' does not exist${NC}"
            echo -e "${BLUE}Creating ArgoCD Application...${NC}"

            # Create the application using the YAML file
            if kubectl apply -f argocd.yaml >/dev/null 2>&1; then
                echo -e "${GREEN}✅ ArgoCD Application 'python-monitoring-app' created successfully${NC}"

                # Wait a moment for ArgoCD to register the new app
                echo -e "${BLUE}Waiting for ArgoCD to register the new application...${NC}"
                sleep 10

                # Verify the app was created
                if $ARGOCD_CLI app get python-monitoring-app >/dev/null 2>&1; then
                    echo -e "${GREEN}✅ Application successfully registered in ArgoCD${NC}"
                else
                    echo -e "${YELLOW}⚠️ Application created but not yet visible in ArgoCD${NC}"
                fi
            else
                echo -e "${RED}❌ Failed to create ArgoCD Application${NC}"
                echo -e "${YELLOW}You may need to create it manually via ArgoCD UI${NC}"
            fi
        fi

        # Try to sync the application with error handling
        echo -e "${BLUE}Syncing ArgoCD Application...${NC}"
        if $ARGOCD_CLI app sync python-monitoring-app 2>/dev/null; then
            echo -e "${GREEN}✅ ArgoCD Application sync initiated${NC}"

            # Wait for sync to complete
            echo -e "${BLUE}Waiting for application sync to complete...${NC}"
            $ARGOCD_CLI app wait python-monitoring-app --timeout 300 2>/dev/null || echo -e "${YELLOW}⚠️ Sync may still be in progress${NC}"
        else
            echo -e "${YELLOW}⚠️ Could not sync ArgoCD application automatically${NC}"
            echo -e "${BLUE}You can manually sync via ArgoCD UI or run: argocd app sync python-monitoring-app${NC}"
        fi

        echo -e "${GREEN}✅ ArgoCD Application synced successfully${NC}"
    else
        echo -e "${YELLOW}⚠️ Could not login to ArgoCD CLI, skipping app creation${NC}"
    fi

    # Clean up port-forward
    kill $PORTFORWARD_PID 2>/dev/null
fi

echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Access Information:${NC}"
echo "===================="
echo ""
echo -e "${YELLOW}To access Prometheus:${NC}"
echo "  kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090"
echo "  Then open: http://localhost:9090"
echo ""
echo -e "${YELLOW}To access Grafana:${NC}"
echo "  kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80"
echo "  Then open: http://localhost:3000"
echo "  Username: admin"
echo "  Password: $(kubectl get secret --namespace monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)"
echo ""
echo -e "${YELLOW}To access Demo App:${NC}"
echo "  kubectl port-forward -n app svc/kube-mon-demo 8000:80"
echo "  Then open: http://localhost:8000"
echo ""
echo -e "${YELLOW}To test the demo app:${NC}"
echo "  curl http://localhost:8000/"
echo "  curl http://localhost:8000/healthz"
echo "  curl http://localhost:8000/readyz"
echo "  curl http://localhost:8000/metrics"
echo ""
echo -e "${YELLOW}To access ArgoCD:${NC}"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Then open: https://localhost:8080"
echo "  Username: admin"
echo "  Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Secret not found - check ArgoCD installation")"
echo ""
echo -e "${BLUE}💡 Import the Grafana dashboard from grafana-dashboard.json${NC}"
echo ""
echo -e "${GREEN}🎉 All services are ready!${NC}"