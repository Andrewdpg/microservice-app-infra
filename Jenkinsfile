pipeline {
  agent any

  environment {
    K8S_NAMESPACE_STAGING = 'microservices-staging'
    K8S_NAMESPACE_PROD = 'microservices-prod'
    KUBECONFIG_CREDENTIAL = 'kubeconfig'
  }

  options {
    skipDefaultCheckout()
    timestamps()
  }

  parameters {
    string(name: 'IMAGE_TAG', defaultValue: 'latest', description: 'Docker image tag to deploy')
    string(name: 'REGISTRY', defaultValue: 'docker.io/andrewdpg', description: 'Docker registry URL')
    string(name: 'TRIGGERED_BY', defaultValue: '', description: 'URL of the build that triggered this deployment')
    string(name: 'GIT_COMMIT', defaultValue: '', description: 'Git commit hash')
    string(name: 'GIT_BRANCH', defaultValue: 'master', description: 'Git branch')
    choice(name: 'ENVIRONMENT', choices: ['staging', 'production'], description: 'Target environment')
    booleanParam(name: 'FORCE_DEPLOY', defaultValue: false, description: 'Force deployment even if no changes detected')
  }

  stages {
    stage('Checkout Infrastructure') {
      steps {
        deleteDir()
        checkout scm
        script {
          env.DEPLOY_TIMESTAMP = sh(script: 'date +%Y%m%d-%H%M%S', returnStdout: true).trim()
          echo "Deploying with tag: ${params.IMAGE_TAG}"
          echo "Registry: ${params.REGISTRY}"
          echo "Environment: ${params.ENVIRONMENT}"
        }
        stash name: 'infra-ws', includes: '**/*'
      }
    }

    stage('Validate Manifests') {
      steps {
        unstash 'infra-ws'
        withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIAL}", variable: 'KCFG')]) {
          script {
            echo "Validating Kubernetes manifests..."
          
            // Validar sintaxis de manifiestos (solo si kubectl está disponible)
            sh '''
              if command -v kubectl >/dev/null 2>&1; then
                find k8s/ -name "*.yaml" -exec kubectl --dry-run=client apply -f {} \\;
              else
                echo "kubectl not available, skipping validation"
              fi
            '''
          }
        }
      }
    }

    stage('Prepare Deployment') {
      steps {
        unstash 'infra-ws'
        script {
          // Crear directorio temporal para renderizar manifiestos
          sh '''
            rm -rf k8s/_render && mkdir -p k8s/_render
            
            # Renderizar manifiestos con variables de entorno
            export REGISTRY="${REGISTRY}"
            export IMAGE_TAG="${IMAGE_TAG}"
            export NAMESPACE="${K8S_NAMESPACE_STAGING}"
            
            if [ "${ENVIRONMENT}" = "production" ]; then
              export NAMESPACE="${K8S_NAMESPACE_PROD}"
            fi
            
            # Copiar y renderizar manifiestos base
            cp k8s/base/*.yaml k8s/_render/

            # Renderizar manifiestos base con variables expandidas
            find k8s/base -type f -name "*.yaml" \
              -print | while read -r f; do
              out="k8s/_render/${f#k8s/base/}"
              mkdir -p "$(dirname "$out")"
              sed -e "s|\\${REGISTRY}|${REGISTRY}|g" \
                  -e "s|\\${IMAGE_TAG}|${IMAGE_TAG}|g" \
                  -e "s|\\${NAMESPACE}|${NAMESPACE}|g" \
                  "$f" > "$out"
            done
            
            # Renderizar SOLO manifiestos del entorno específico
            if [ -d "k8s/${ENVIRONMENT}" ]; then
              find k8s/${ENVIRONMENT} -type f -name "*.yaml" \
                -print | while read -r f; do
                out="k8s/_render/${f#k8s/${ENVIRONMENT}/}"
                mkdir -p "$(dirname "$out")"
                sed -e "s|\\${REGISTRY}|${REGISTRY}|g" \
                    -e "s|\\${IMAGE_TAG}|${IMAGE_TAG}|g" \
                    -e "s|\\${NAMESPACE}|${NAMESPACE}|g" \
                    "$f" > "$out"
              done
            fi
            
            echo "Rendered files for ${ENVIRONMENT}:"
            find k8s/_render -type f -print
          '''
        }
      }
    }

    stage('Deploy to Staging') {
      when {
        anyOf {
          equals expected: 'staging', actual: params.ENVIRONMENT
          equals expected: 'production', actual: params.ENVIRONMENT
        }
      }
      steps {
        unstash 'infra-ws'
        withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIAL}", variable: 'KCFG')]) {
          script {
            echo "Deploying to staging environment..."
            sh '''
              set -e
              export KUBECONFIG="$KCFG"
              
              # Verificar que kubectl funciona
              kubectl version --client
              
              # Aplicar namespaces primero
              kubectl apply -f k8s/_render/namespaces.yaml
              
              # Aplicar configuración
              kubectl apply -f k8s/_render/configmap.yaml
              kubectl apply -f k8s/_render/secret.yaml
              
              # Aplicar todos los manifiestos del entorno
              kubectl apply -f k8s/_render -R
              
              # Esperar a que los deployments estén listos
              kubectl rollout status deployment/auth-api -n ${K8S_NAMESPACE_STAGING} --timeout=300s
              kubectl rollout status deployment/users-api -n ${K8S_NAMESPACE_STAGING} --timeout=300s
              kubectl rollout status deployment/todos-api -n ${K8S_NAMESPACE_STAGING} --timeout=300s
              kubectl rollout status deployment/frontend -n ${K8S_NAMESPACE_STAGING} --timeout=300s
              kubectl rollout status deployment/log-processor -n ${K8S_NAMESPACE_STAGING} --timeout=300s
            '''
          }
        }
      }
    }

    stage('Health Check Staging') {
      when {
        anyOf {
          equals expected: 'staging', actual: params.ENVIRONMENT
          equals expected: 'production', actual: params.ENVIRONMENT
        }
      }
      steps {
        unstash 'infra-ws'
        withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIAL}", variable: 'KCFG')]) {
          script {
            echo "Performing health checks on staging..."
            sh '''
              export KUBECONFIG="$KCFG"
              
              # Verificar que todos los pods están corriendo
              kubectl get pods -n ${K8S_NAMESPACE_STAGING}
              
              # Health checks básicos
              if [ -f "./scripts/health-check.sh" ]; then
                ./scripts/health-check.sh ${K8S_NAMESPACE_STAGING}
              else
                echo "Health check script not found, skipping"
              fi
            '''
          }
        }
      }
    }

    stage('Deploy to Production (Execute)') {
      when {
        equals expected: 'production', actual: params.ENVIRONMENT
      }
      steps {
        unstash 'infra-ws'
        withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIAL}", variable: 'KCFG')]) {
          script {
            echo "Deploying to production environment..."
            sh '''
              set -e
              export KUBECONFIG="$KCFG"
              export NAMESPACE="${K8S_NAMESPACE_PROD}"
              
              # Re-renderizar para producción
              rm -rf k8s/_render-prod && mkdir -p k8s/_render-prod
              
              # Copiar base
              cp k8s/base/*.yaml k8s/_render-prod/

              # Renderizar base para producción
              find k8s/base -type f -name "*.yaml" \
                -print | while read -r f; do
                out="k8s/_render-prod/${f#k8s/base/}"
                mkdir -p "$(dirname "$out")"
                sed -e "s|\\${REGISTRY}|${REGISTRY}|g" \
                    -e "s|\\${IMAGE_TAG}|${IMAGE_TAG}|g" \
                    -e "s|\\${NAMESPACE}|${NAMESPACE}|g" \
                    "$f" > "$out"
              done
              
              # Renderizar para producción
              find k8s/production -type f -name "*.yaml" \
                -print | while read -r f; do
                out="k8s/_render-prod/${f#k8s/production/}"
                mkdir -p "$(dirname "$out")"
                sed -e "s|\\${REGISTRY}|${REGISTRY}|g" \
                    -e "s|\\${IMAGE_TAG}|${IMAGE_TAG}|g" \
                    -e "s|\\${NAMESPACE}|${NAMESPACE}|g" \
                    "$f" > "$out"
              done
              
              # Aplicar a producción
              kubectl apply -f k8s/_render-prod -R
              
              # Esperar rollouts
              kubectl rollout status deployment/auth-api -n ${K8S_NAMESPACE_PROD} --timeout=600s
              kubectl rollout status deployment/users-api -n ${K8S_NAMESPACE_PROD} --timeout=600s
              kubectl rollout status deployment/todos-api -n ${K8S_NAMESPACE_PROD} --timeout=600s
              kubectl rollout status deployment/frontend -n ${K8S_NAMESPACE_PROD} --timeout=600s
              kubectl rollout status deployment/log-processor -n ${K8S_NAMESPACE_PROD} --timeout=600s
            '''
          }
        }
      }
    }

    stage('Health Check Production') {
      when {
        equals expected: 'production', actual: params.ENVIRONMENT
      }
      steps {
        unstash 'infra-ws'
        withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIAL}", variable: 'KCFG')]) {
          script {
            echo "Performing health checks on production..."
            sh '''
              export KUBECONFIG="$KCFG"
              
              # Verificar que todos los pods están corriendo
              kubectl get pods -n ${K8S_NAMESPACE_PROD}
              
              # Health checks básicos
              if [ -f "./scripts/health-check.sh" ]; then
                ./scripts/health-check.sh ${K8S_NAMESPACE_PROD}
              else
                echo "Health check script not found, skipping"
              fi
            '''
          }
        }
      }
    }
  }

  post {
    always {
      // Limpiar archivos temporales
      sh '''
        rm -rf k8s/_render k8s/_render-prod
      '''
    }
    
    success {
      echo "Deployment to ${params.ENVIRONMENT} completed successfully"
      script {
        if (params.ENVIRONMENT == 'staging') {
          echo "Staging deployment ready for testing"
        } else {
          echo "Production deployment completed"
        }
      }
    }
    
    failure {
      echo "Deployment to ${params.ENVIRONMENT} failed"
      script {
        echo "Consider rolling back the deployment"
      }
    }
  }
}