FROM jenkins/jenkins:lts-jdk17

# Instalar Docker y kubectl
USER root
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io \
    && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Agregar jenkins al grupo docker
RUN usermod -aG docker jenkins

# Volver al usuario jenkins
USER jenkins

# Instalar solo plugins esenciales que existen
RUN jenkins-plugin-cli --plugins \
    kubernetes \
    workflow-aggregator \
    git \
    credentials-binding \
    docker-workflow \
    blueocean \
    github \
    github-branch-source \
    timestamper \
    build-timeout \
    htmlpublisher \
    gradle \
    junit \
    mailer \
    ldap \
    matrix-auth \
    matrix-project \
    ant \
    ssh-credentials \
    ssh-slaves \
    plain-credentials \
    token-macro \
    favorite \
    display-url-api \
    checks-api \
    cloud-stats \
    metrics \
    variant \
    structs \
    script-security \
    durable-task