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
