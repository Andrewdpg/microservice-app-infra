# scripts/gen-jenkins-config.ps1
param(
    [string]$ClusterName = "ci",
    [string]$Namespace = "microservices-staging",  # ← Cambiar default
    [string]$ServiceAccount = "jenkins-deployer",
    [string]$Output = "jenkins-kubeconfig.yaml",
    [switch]$ConnectJenkinsToKindNet = $true,
    [string]$JenkinsUrl = "http://localhost:8079"
)

Write-Host "Generando kubeconfig para SA '$ServiceAccount' en ns '$Namespace'..." -ForegroundColor Yellow

# 1) Asegurar namespaces y RBAC
if (Test-Path "k8s/base/namespaces.yaml") {
    kubectl apply -f k8s/base/namespaces.yaml | Out-Null
}
else {
    kubectl get ns $Namespace 2>$null 1>$null
    if ($LASTEXITCODE -ne 0) { kubectl create ns $Namespace | Out-Null }
}

# 2) Esperar SA
$retries = 20
do {
    $saOk = kubectl -n $Namespace get sa $ServiceAccount 2>$null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 1
    $retries--
} while ($retries -gt 0)

if ($LASTEXITCODE -ne 0) {
    Write-Host "No se encontró el ServiceAccount $ServiceAccount en $Namespace" -ForegroundColor Red
    exit 1
}

# 3) Obtener token
$token = ""
try {
    $token = (kubectl -n $Namespace create token $ServiceAccount --duration=8760h 2>$null).Trim()
}
catch { }

if (-not $token) {
    $saJson = kubectl -n $Namespace get sa $ServiceAccount -o json
    $secretName = (ConvertFrom-Json $saJson).secrets[0].name
    $tokenB64 = kubectl -n $Namespace get secret $secretName -o jsonpath='{.data.token}'
    $token = [Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($tokenB64))
}

if (-not $token) {
    Write-Host "No se pudo obtener token para $ServiceAccount" -ForegroundColor Red
    exit 1
}

# 4) CA y server desde kubeconfig de kind
$kindCfg = kind get kubeconfig --name $ClusterName
$caData = ($kindCfg | Select-String -Pattern 'certificate-authority-data:\s*(\S+)' -AllMatches).Matches[0].Groups[1].Value
$kindSrv = ($kindCfg | Select-String -Pattern 'server:\s*(\S+)' -AllMatches).Matches[0].Groups[1].Value

# 5) Server a usar
$server = "https://$ClusterName-control-plane:6443"

# 6) Construir kubeconfig
$kcfg = @"
apiVersion: v1
kind: Config
clusters:
- name: kind-$ClusterName
  cluster:
    server: $server
    certificate-authority-data: $caData
contexts:
- name: $ServiceAccount@kind-$ClusterName
  context:
    cluster: kind-$ClusterName
    user: $ServiceAccount
    namespace: $Namespace
current-context: $ServiceAccount@kind-$ClusterName
users:
- name: $ServiceAccount
  user:
    token: $token
"@

$kcfg | Out-File -FilePath $Output -Encoding UTF8
Write-Host "Kubeconfig generado: $Output" -ForegroundColor Green

# 7) Conectar contenedor Jenkins a la red 'kind'
if ($ConnectJenkinsToKindNet) {
    $jenkins = (docker ps --filter "name=jenkins" --format "{{.Names}}")
    if ($jenkins) {
        Write-Host "Conectando contenedor '$jenkins' a la red 'kind'..." -ForegroundColor Yellow
        docker network connect kind $jenkins 2>$null
    }
    else {
        Write-Host "No se encontró contenedor 'jenkins'; omitiendo conexión a red kind." -ForegroundColor Gray
    }
}

# 8) Prueba rápida con el kubeconfig generado
Write-Host "Probando acceso con kubeconfig..." -ForegroundColor Yellow
kubectl --kubeconfig $Output -n $Namespace auth can-i get pods | Write-Host