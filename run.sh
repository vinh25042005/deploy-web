#!/bin/bash
# run.sh — 1 lệnh: tạo VM + cài monitoring stack
# Usage: ./run.sh
# Config: sửa các biến trong config.sh

set -e
source config.sh

echo "============================================"
echo " STEP 1: Terraform — Tạo EC2 VM"
echo "============================================"
cd terraform
terraform init -input=false
terraform apply -auto-approve -input=false \
  -var="region=${AWS_REGION}" \
  -var="instance_type=${EC2_INSTANCE_TYPE}" \
  -var="key_name=${EC2_KEY_NAME}"
VM_IP=$(terraform output -raw public_ip)
cd ..
echo "✅ VM đã tạo: $VM_IP"

echo ""
echo "============================================"
echo " STEP 2: Đợi SSH sẵn sàng..."
echo "============================================"
for i in $(seq 1 30); do
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
    -i "${SSH_KEY_PATH}" "${SSH_USER}@${VM_IP}" "echo OK" 2>/dev/null; then
    echo "✅ SSH sẵn sàng!"
    break
  fi
  echo ">>> Đợi... ($i/30)"
  sleep 10
done

echo ""
echo "============================================"
echo " STEP 3: Ansible — Cài monitoring stack"
echo "============================================"
cd ansible
ansible-playbook playbooks/monitoring.yml \
  -e "monitoring_host=${VM_IP}" \
  -e "ansible_user=${SSH_USER}" \
  -e "ssh_key_path=${SSH_KEY_PATH}"
cd ..

echo ""
echo "============================================"
echo " HOÀN THÀNH!"
echo " Prometheus:  http://${VM_IP}:${PROMETHEUS_PORT:-9090}"
echo " Grafana:     http://${VM_IP}:${GRAFANA_PORT:-3000} (admin / xem vault.yml)"
echo " Node Exp:    http://${VM_IP}:${NODE_EXPORTER_PORT:-9100}/metrics"
echo ""
echo " SSH:         ssh -i ${SSH_KEY_PATH} ${SSH_USER}@${VM_IP}"
echo "============================================"
