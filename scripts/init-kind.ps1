param([string]$ClusterName="ci", [string]$Namespace="microservices-staging")
Write-Host "Creando/verificando cluster kind '$ClusterName'..."
$exists = kind get clusters | Select-String -SimpleMatch $ClusterName
if (-not $exists) {
  kind create cluster --name $ClusterName --config k8s/kind.yaml
} else {
  Write-Host "Cluster ya existe."
}
kubectl cluster-info

docker network connect kind jenkins

Write-Host "Aplicando namespaces + RBAC..."
kubectl apply -f k8s/base/namespaces.yaml
kubectl apply -f k8s/rbac-jenkins.yaml

Write-Host "Aplicando config (ConfigMap/Secret) con namespace $Namespace..."
# Expandir variables en los archivos YAML antes de aplicarlos
$configMapContent = Get-Content "k8s/base/configmap.yaml" -Raw
$configMapContent = $configMapContent -replace '\$\{NAMESPACE\}', $Namespace
$configMapContent | kubectl apply -f -

$secretContent = Get-Content "k8s/base/secret.yaml" -Raw  
$secretContent = $secretContent -replace '\$\{NAMESPACE\}', $Namespace
$secretContent | kubectl apply -f -