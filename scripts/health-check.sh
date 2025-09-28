#!/bin/bash

# Health Check Script for Microservices
# Usage: ./health-check.sh <kubeconfig> <namespace> [timeout]

set -e

KUBECONFIG=${1:-}  # Primer parámetro: ruta al kubeconfig
NAMESPACE=${2:-microservices-staging}  # Segundo parámetro: namespace
TIMEOUT=${3:-300}  # Tercer parámetro: timeout
INTERVAL=10

echo "🔍 Performing health checks on namespace: $NAMESPACE"
echo "⏱️  Timeout: ${TIMEOUT}s, Interval: ${INTERVAL}s"
echo "🔧 Using kubeconfig: $KUBECONFIG"

# Función para verificar si un deployment está listo
check_deployment() {
    local deployment=$1
    local namespace=$2
    
    echo "Checking deployment: $deployment"
    
    if ! kubectl --kubeconfig="$KUBECONFIG" get deployment $deployment -n $namespace >/dev/null 2>&1; then
        echo "❌ Deployment $deployment not found in namespace $namespace"
        return 1
    fi
    
    # Verificar que el deployment está listo
    if ! kubectl --kubeconfig="$KUBECONFIG" rollout status deployment/$deployment -n $namespace --timeout=${TIMEOUT}s; then
        echo "❌ Deployment $deployment is not ready"
        return 1
    fi
    
    # Verificar que todos los pods están corriendo
    local ready_pods=$(kubectl --kubeconfig="$KUBECONFIG" get deployment $deployment -n $namespace -o jsonpath='{.status.readyReplicas}')
    local desired_pods=$(kubectl --kubeconfig="$KUBECONFIG" get deployment $deployment -n $namespace -o jsonpath='{.spec.replicas}')
    
    if [ "$ready_pods" != "$desired_pods" ]; then
        echo "❌ Deployment $deployment: $ready_pods/$desired_pods pods ready"
        return 1
    fi
    
    echo "✅ Deployment $deployment is healthy"
    return 0
}

# Función para verificar endpoints
check_endpoints() {
    local service=$1
    local namespace=$2
    local port=$3
    
    echo "Checking service endpoints: $service"
    
    if ! kubectl --kubeconfig="$KUBECONFIG" get service $service -n $namespace >/dev/null 2>&1; then
        echo "❌ Service $service not found in namespace $namespace"
        return 1
    fi
    
    # Verificar que el servicio tiene endpoints
    local endpoints=$(kubectl --kubeconfig="$KUBECONFIG" get endpoints $service -n $namespace -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
    
    if [ -z "$endpoints" ]; then
        echo "❌ Service $service has no endpoints"
        return 1
    fi
    
    echo "✅ Service $service has endpoints: $endpoints"
    return 0
}

# Lista de servicios a verificar
declare -A SERVICES=(
    ["auth-api"]="8081"
    ["users-api"]="8083"
    ["todos-api"]="8082"
    ["frontend"]="8080"
    ["log-processor"]="8080"
)

declare -A DEPLOYMENTS=(
    ["auth-api"]="auth-api"
    ["users-api"]="users-api"
    ["todos-api"]="todos-api"
    ["frontend"]="frontend"
    ["log-processor"]="log-processor"
)

echo "🚀 Starting health checks..."

# Verificar que el namespace existe
if ! kubectl --kubeconfig="$KUBECONFIG" get namespace $NAMESPACE >/dev/null 2>&1; then
    echo "❌ Namespace $NAMESPACE not found"
    exit 1
fi

# Verificar deployments
echo "📋 Checking deployments..."
for service in "${!DEPLOYMENTS[@]}"; do
    deployment="${DEPLOYMENTS[$service]}"
    if ! check_deployment $deployment $NAMESPACE; then
        echo "❌ Health check failed for deployment: $deployment"
        exit 1
    fi
done

# Verificar servicios
echo "🌐 Checking services..."
for service in "${!SERVICES[@]}"; do
    port="${SERVICES[$service]}"
    if ! check_endpoints $service $NAMESPACE $port; then
        echo "❌ Health check failed for service: $service"
        exit 1
    fi
done

# Verificar recursos del cluster
echo "📊 Checking cluster resources..."
kubectl --kubeconfig="$KUBECONFIG" top pods -n $NAMESPACE 2>/dev/null || echo "⚠️  Metrics not available"

# Verificar eventos recientes
echo "📝 Recent events:"
kubectl --kubeconfig="$KUBECONFIG" get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10

echo "✅ All health checks passed for namespace: $NAMESPACE"
echo "🎉 Deployment is healthy and ready!"