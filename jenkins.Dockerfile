FROM jenkins/jenkins:lts-jdk17

# Instalar kubectl
USER root
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Volver al usuario jenkins
USER jenkins

# Instalar plugins necesarios
RUN jenkins-plugin-cli --plugins \
    kubernetes:latest \
    workflow-aggregator:latest \
    git:latest \
    credentials-binding:latest \
    timestamper:latest