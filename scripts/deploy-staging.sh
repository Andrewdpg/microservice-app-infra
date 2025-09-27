#!/bin/bash

# Deploy to Staging Environment
# Usage: ./deploy-staging.sh [image-tag] [registry]

set -e

IMAGE_TAG=${1:-latest}
REGISTRY=${2:-docker.io/andrewdpg}
NAMESPACE="microservices-staging"
TIMEOUT=300

echo "🚀 Deploying to staging environment..."
echo "📦 Image Tag: $IMAGE_TAG"
echo "🏷️  Registry: $REGISTRY"
echo "📁 Namespace: $NAMESPACE"

# Verificar que kubectl está disponible
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Verificar que el contexto de Kubernetes es correcto
echo "🔍 Current Kubernetes context:"
kubectl config current-context

# Crear namespace si no existe
echo "📁 Creating namespace if it doesn't exist..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Aplicar configuración base
echo "⚙️  Applying base configuration..."
kubectl apply -f k8s/base/namespaces.yaml
kubectl apply -f k8s/base/configmap.yaml
kubectl apply -f k8s/base/secret.yaml

# Renderizar y aplicar manifiestos de staging
echo "🔧 Rendering staging manifests..."
rm -rf k8s/_render && mkdir -p k8s/_render

# Copiar manifiestos base
cp k8s/base/*.yaml k8s/_render/

# Renderizar manifiestos específicos de staging
find k8s/staging -type f -name "*.yaml" -print | while read -r f; do
    out="k8s/_render/${f#k8s/staging/}"
    mkdir -p "$(dirname "$out")"
    sed -e "s|\\\${REGISTRY}|${REGISTRY}|g" \
        -e "s|\\\${IMAGE_TAG}|${IMAGE_TAG}|g" \
        -e "s|\\\${NAMESPACE}|${NAMESPACE}|g" \
        "$f" > "$out"
done

echo "📋 Rendered files:"
find k8s/_render -type f -print

# Aplicar servicios primero
echo "🌐 Applying services..."
kubectl apply -f k8s/_render -R --selector=type=service

# Aplicar deployments
echo "🚀 Applying deployments..."
kubectl apply -f k8s/_render -R --selector=type=deployment

# Aplicar HPA
echo "📈 Applying HPA..."
kubectl apply -f k8s/_render -R --selector=type=hpa

# Esperar a que los deployments estén listos
echo "⏳ Waiting for deployments to be ready..."
kubectl rollout status deployment/auth-api -n $NAMESPACE --timeout=${TIMEOUT}s
kubectl rollout status deployment/users-api -n $NAMESPACE --timeout=${TIMEOUT}s
kubectl rollout status deployment/todos-api -n $NAMESPACE --timeout=${TIMEOUT}s
kubectl rollout status deployment/frontend -n $NAMESPACE --timeout=${TIMEOUT}s
kubectl rollout status deployment/log-processor -n $NAMESPACE --timeout=${TIMEOUT}s

# Verificar el estado de los pods
echo "🔍 Checking pod status..."
kubectl get pods -n $NAMESPACE

# Ejecutar health checks
echo "🏥 Running health checks..."
./scripts/health-check.sh $NAMESPACE

# Mostrar información de acceso
echo "🌐 Access information:"
echo "Namespace: $NAMESPACE"
echo "Services:"
kubectl get services -n $NAMESPACE

echo "✅ Staging deployment completed successfully!"
echo "🎉 Application is ready for testing"
