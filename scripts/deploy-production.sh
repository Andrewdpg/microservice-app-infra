#!/bin/bash

# Deploy to Production Environment
# Usage: ./deploy-production.sh [image-tag] [registry]

set -e

IMAGE_TAG=${1:-latest}
REGISTRY=${2:-docker.io/andrewdpg}
NAMESPACE="microservices-prod"
TIMEOUT=600

echo "🚀 Deploying to production environment..."
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

# Confirmación de seguridad
echo "⚠️  WARNING: You are about to deploy to PRODUCTION!"
echo "📦 Image Tag: $IMAGE_TAG"
echo "🏷️  Registry: $REGISTRY"
read -p "Are you sure you want to continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "❌ Deployment cancelled by user"
    exit 1
fi

# Crear namespace si no existe
echo "📁 Creating namespace if it doesn't exist..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Aplicar configuración base
echo "⚙️  Applying base configuration..."
kubectl apply -f k8s/base/namespaces.yaml
kubectl apply -f k8s/base/configmap.yaml
kubectl apply -f k8s/base/secret.yaml

# Renderizar y aplicar manifiestos de producción
echo "🔧 Rendering production manifests..."
rm -rf k8s/_render-prod && mkdir -p k8s/_render-prod

# Copiar manifiestos base
cp k8s/base/*.yaml k8s/_render-prod/

# Renderizar manifiestos específicos de producción
find k8s/production -type f -name "*.yaml" -print | while read -r f; do
    out="k8s/_render-prod/${f#k8s/production/}"
    mkdir -p "$(dirname "$out")"
    sed -e "s|\\\${REGISTRY}|${REGISTRY}|g" \
        -e "s|\\\${IMAGE_TAG}|${IMAGE_TAG}|g" \
        -e "s|\\\${NAMESPACE}|${NAMESPACE}|g" \
        "$f" > "$out"
done

echo "📋 Rendered files:"
find k8s/_render-prod -type f -print

# Aplicar servicios primero
echo "🌐 Applying services..."
kubectl apply -f k8s/_render-prod -R --selector=type=service

# Aplicar deployments
echo "🚀 Applying deployments..."
kubectl apply -f k8s/_render-prod -R --selector=type=deployment

# Aplicar HPA
echo "📈 Applying HPA..."
kubectl apply -f k8s/_render-prod -R --selector=type=hpa

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

# Mostrar métricas de recursos
echo "📊 Resource usage:"
kubectl top pods -n $NAMESPACE 2>/dev/null || echo "⚠️  Metrics not available"

echo "✅ Production deployment completed successfully!"
echo "🎉 Application is live in production!"
