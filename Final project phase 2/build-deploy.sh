#!/bin/bash
set -e  # Stop on first error

echo "🚀 Starting Minikube with Docker driver..."
minikube start --driver=docker

echo "🔧 Enabling required Minikube addons..."
minikube addons enable storage-provisioner
minikube addons enable default-storageclass
minikube addons enable metrics-server

echo "📦 Applying Kubernetes secrets..."
kubectl apply -f earthquake-secret.yaml

echo "📄 Deploying application..."
kubectl apply -f deploy.yaml

echo "⏳ Waiting for Earthquake deployment to become available..."
kubectl rollout status deployment/earthquake --timeout=180s || {
  echo "❌ Deployment failed. Check pod logs with: kubectl logs -l app=earthquake"
  exit 1
}

echo "🌐 Opening service in browser..."
minikube service earthquake-service

echo "✅ Deployment completed!"