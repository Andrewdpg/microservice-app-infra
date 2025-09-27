# Microservice Infrastructure Repository

Este repositorio contiene toda la configuración de infraestructura para el proyecto de microservicios.

## 📁 **Estructura**

```
microservice-infrastructure/
├── README.md
├── Jenkinsfile                    # Pipeline de infraestructura
├── .gitignore
├── k8s/
│   ├── base/                     # Manifiestos base
│   │   ├── namespaces.yaml
│   │   ├── configmap.yaml
│   │   └── secret.yaml
│   ├── staging/                  # Configuración de staging
│   │   ├── auth-api/
│   │   ├── users-api/
│   │   ├── todos-api/
│   │   ├── frontend/
│   │   ├── log-processor/
│   │   └── redis/
│   └── production/               # Configuración de producción
│       ├── auth-api/
│       ├── users-api/
│       ├── todos-api/
│       ├── frontend/
│       ├── log-processor/
│       └── redis/
├── scripts/
│   ├── deploy-staging.sh
│   ├── deploy-production.sh
│   ├── rollback.sh
│   └── health-check.sh
└── .env.example
```

## 🚀 **Uso**

### **Deploy a Staging**
```bash
./scripts/deploy-staging.sh
```

### **Deploy a Producción**
```bash
./scripts/deploy-production.sh
```

### **Rollback**
```bash
./scripts/rollback.sh microservices-staging
```

## 🔧 **Configuración**

1. Copiar `.env.example` a `.env`
2. Configurar credenciales en Jenkins
3. Configurar kubeconfig para staging y producción
