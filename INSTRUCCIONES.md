# 📁 **ARCHIVOS PARA EL REPO DE INFRAESTRUCTURA**

## 🎯 **RESPUESTA A TUS PREGUNTAS**

### **¿Cuándo se usan los scripts .sh?**

Los scripts se usan en **3 momentos**:

1. **En el Jenkinsfile** (automáticamente):
   - `health-check.sh` - Después de cada deploy
   - `deploy-staging.sh` - Para deploy automático a staging
   - `deploy-production.sh` - Para deploy a producción

2. **Manualmente** (cuando necesites):
   - `./scripts/deploy-staging.sh` - Deploy manual a staging
   - `./scripts/deploy-production.sh` - Deploy manual a producción
   - `./scripts/rollback.sh` - Rollback cuando algo falle

3. **En Jenkins** (configurado):
   - Jenkins ejecuta los scripts automáticamente
   - No necesitas ejecutarlos manualmente

## 📦 **ARCHIVOS LISTOS PARA COPIAR**

**Copia toda la carpeta `infra-repo-files/` al nuevo repo de infraestructura:**

```bash
# Crear el nuevo repo
mkdir ../microservice-infrastructure
cd ../microservice-infrastructure

# Copiar todos los archivos
cp -r ../microservice-app-example/infra-repo-files/* .

# Inicializar git
git init
git add .
git commit -m "Initial infrastructure setup"
git remote add origin <tu-repo-infra-url>
git push -u origin main
```

## 🗂️ **ESTRUCTURA FINAL DEL REPO DE INFRA**

```
microservice-infrastructure/
├── README.md
├── Jenkinsfile                    # ← Pipeline de infraestructura
├── .gitignore
├── env.example
├── k8s/
│   ├── base/                     # ← Manifiestos base
│   │   ├── namespaces.yaml
│   │   ├── configmap.yaml
│   │   └── secret.yaml
│   ├── staging/                  # ← Configuración de staging
│   │   └── auth-api/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       └── hpa.yaml
│   └── production/               # ← Configuración de producción
│       └── (misma estructura)
└── scripts/
    ├── deploy-staging.sh         # ← Deploy a staging
    ├── deploy-production.sh      # ← Deploy a producción
    ├── rollback.sh              # ← Rollback
    └── health-check.sh          # ← Health checks
```

## 🚀 **PASOS PARA IMPLEMENTAR**

### **1. Crear el repo de infraestructura**
```bash
# Crear directorio
mkdir ../microservice-infrastructure
cd ../microservice-infrastructure

# Copiar archivos
cp -r ../microservice-app-example/infra-repo-files/* .

# Inicializar git
git init
git add .
git commit -m "Initial infrastructure setup"
```

### **2. Configurar Jenkins de infraestructura**
- **Job**: `microservice-infrastructure-deploy`
- **Tipo**: Pipeline
- **Script**: `Jenkinsfile`
- **Credenciales**: `kubeconfig-staging`, `kubeconfig-production`

### **3. Modificar el repo de microservicios**
```bash
# En el repo de microservicios, reemplazar Jenkinsfile
mv Jenkinsfile Jenkinsfile.old
# Crear nuevo Jenkinsfile que solo haga CI y llame al Jenkins de infra
```

## 🔄 **FLUJO COMPLETO**

```
1. Push a main en repo de microservicios
   ↓
2. Jenkins de microservicios:
   - Build + Test + Push imágenes
   - Llama al Jenkins de infraestructura
   ↓
3. Jenkins de infraestructura:
   - Deploy automático a staging
   - Health checks
   - [Manual] Deploy a producción
```

## 📝 **NOTAS IMPORTANTES**

- ✅ **Solo copia la carpeta `infra-repo-files/`**
- ✅ **No toques los archivos de tu repo actual**
- ✅ **Los scripts se ejecutan automáticamente en Jenkins**
- ✅ **Puedes ejecutar los scripts manualmente si necesitas**

**¡Listo! Solo copia la carpeta y configura Jenkins!** 🚀
