#!/bin/bash

# Rollback Script for Microservices
# Usage: ./rollback.sh <namespace> [deployment-name]

set -e

NAMESPACE=${1:-microservices-staging}
DEPLOYMENT=${2:-all}
TIMEOUT=300

echo "🔄 Rolling back deployment in namespace: $NAMESPACE"
echo "📦 Deployment: $DEPLOYMENT"

# Verificar que kubectl está disponible
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Verificar que el namespace existe
if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    echo "❌ Namespace $NAMESPACE not found"
    exit 1
fi

# Función para hacer rollback de un deployment específico
rollback_deployment() {
    local deployment=$1
    local namespace=$2
    
    echo "🔄 Rolling back deployment: $deployment"
    
    if ! kubectl get deployment $deployment -n $namespace >/dev/null 2>&1; then
        echo "❌ Deployment $deployment not found in namespace $namespace"
        return 1
    fi
    
    # Verificar el historial de rollouts
    echo "📋 Rollout history for $deployment:"
    kubectl rollout history deployment/$deployment -n $namespace
    
    # Hacer rollback a la versión anterior
    if kubectl rollout undo deployment/$deployment -n $namespace; then
        echo "✅ Rollback initiated for $deployment"
        
        # Esperar a que el rollback se complete
        if kubectl rollout status deployment/$deployment -n $namespace --timeout=${TIMEOUT}s; then
            echo "✅ Rollback completed for $deployment"
            return 0
        else
            echo "❌ Rollback failed for $deployment"
            return 1
        fi
    else
        echo "❌ Failed to initiate rollback for $deployment"
        return 1
    fi
}

# Lista de deployments
declare -a DEPLOYMENTS=("auth-api" "users-api" "todos-api" "frontend" "log-processor")

if [ "$DEPLOYMENT" = "all" ]; then
    echo "🔄 Rolling back all deployments..."
    
    # Rollback en orden inverso (dependencias)
    for deployment in "${DEPLOYMENTS[@]}"; do
        if ! rollback_deployment $deployment $NAMESPACE; then
            echo "❌ Rollback failed for $deployment"
            exit 1
        fi
    done
else
    echo "🔄 Rolling back specific deployment: $DEPLOYMENT"
    
    if ! rollback_deployment $DEPLOYMENT $NAMESPACE; then
        echo "❌ Rollback failed for $DEPLOYMENT"
        exit 1
    fi
fi

# Verificar el estado después del rollback
echo "🔍 Checking status after rollback..."
kubectl get pods -n $NAMESPACE

# Ejecutar health checks
echo "🏥 Running health checks after rollback..."
./scripts/health-check.sh $NAMESPACE

# Mostrar información de rollback
echo "📋 Rollback information:"
for deployment in "${DEPLOYMENTS[@]}"; do
    if kubectl get deployment $deployment -n $NAMESPACE >/dev/null 2>&1; then
        echo "Deployment: $deployment"
        kubectl rollout history deployment/$deployment -n $NAMESPACE | tail -3
        echo "---"
    fi
done

echo "✅ Rollback completed successfully!"
echo "🎉 Application has been rolled back to previous version"
