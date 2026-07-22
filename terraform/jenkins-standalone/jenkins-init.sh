#!/bin/bash
set -euxo pipefail

# ─── Cài Docker ───
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
sudo chmod 666 /var/run/docker.sock

# ─── Cài Node.js ───
sudo apt-get update -qq
sudo apt-get install -y -qq nodejs npm 2>&1 | tail -3

# ─── Tạo thư mục data cho Jenkins với đúng permissions ───
sudo mkdir -p /jenkins-home/init.groovy.d
sudo chown -R 1000:1000 /jenkins-home

# ─── Init Groovy script (tự động skip wizard + tạo admin) ───
cat << 'GEOOF' | sudo tee /jenkins-home/init.groovy.d/01-skip-wizard.groovy
import jenkins.model.*
import hudson.security.*
import jenkins.install.InstallState

def instance = Jenkins.getInstance()

// Tạo admin user
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "admin123")
instance.setSecurityRealm(hudsonRealm)

// Full read/write permission
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

// Skip setup wizard
instance.setInstallState(InstallState.INITIALIZED)
instance.save()
GEOOF
sudo chown 1000:1000 /jenkins-home/init.groovy.d/01-skip-wizard.groovy

# ─── Chạy Jenkins container ───
sudo docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p ${jenkins_port}:8080 \
  -p 50000:50000 \
  -v /jenkins-home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add $(getent group docker | cut -d: -f3) \
  jenkins/jenkins:lts-jdk21

# ─── Đợi Jenkins ready ───
echo "Waiting for Jenkins to be ready..."
for i in $(seq 1 30); do
  if curl -s http://localhost:${jenkins_port}/login > /dev/null 2>&1; then
    echo "Jenkins is ready!"
    break
  fi
  echo "  Waiting... ($i/30)"
  sleep 10
done

# ─── Cài Node.js trong container ───
echo "Installing Node.js inside Jenkins container..."
sudo docker exec -u root jenkins bash -c "
  apt-get update -qq && apt-get install -y -qq curl gnupg 2>&1 | tail -3
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y -qq nodejs 2>&1 | tail -5
  node --version && npm --version
"

# ─── Cài Docker CLI trong container ───
echo "Installing Docker CLI inside Jenkins container..."
sudo docker exec -u root jenkins bash -c "
  curl -fsSL https://get.docker.com | sh
  docker --version
"

# ─── Cài Trivy + Syft trong container ───
echo "Installing Trivy and Syft inside Jenkins container..."
sudo docker exec -u root jenkins bash -c "
  apt-get install -y -qq wget apt-transport-https gnupg 2>&1 | tail -1
  wget -qO- https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor > /usr/share/keyrings/trivy.gpg
  echo 'deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main' > /etc/apt/sources.list.d/trivy.list
  apt-get update -qq 2>/dev/null
  apt-get install -y -qq trivy 2>&1 | tail -2
  trivy --version 2>&1 | head -1
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin 2>&1 | tail -1
  syft --version
"

# ─── Cài nvm + Node 18/20 trong container ───
echo "Installing nvm and multiple Node versions..."
sudo docker exec -u root jenkins bash -c "
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
  export NVM_DIR=/var/jenkins_home/.nvm
  [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
  nvm install 18
  nvm install 20
  chown -R 1000:1000 \$NVM_DIR
"

# ─── Cài plugins ───
echo "Installing plugins..."
sudo docker exec jenkins jenkins-plugin-cli --plugins \
  docker-workflow kubernetes-cli blueocean git pipeline-stage-view \
  credentials-binding matrix-auth workflow-aggregator aws-credentials 2>&1 | tail -5

# ─── Restart ───
sudo docker restart jenkins
sleep 20

echo "========================================"
echo "✅ Jenkins ready: http://$(curl -s http://checkip.amazonaws.com):${jenkins_port}"
echo "   User: admin / Password: admin123"
echo "========================================"
