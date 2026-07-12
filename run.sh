#!/bin/bash
# run.sh — 1 lệnh: tạo VM + cài monitoring stack
# Usage: ./run.sh

set -e

echo "============================================"
echo " STEP 1: Terraform — Tạo EC2 VM"
echo "============================================"
cd terraform
terraform init -input=false
terraform apply -auto-approve -input=false
VM_IP=$(terraform output -raw public_ip)
cd ..
echo "✅ VM đã tạo: $VM_IP"

echo ""
echo "============================================"
echo " STEP 2: Đợi SSH sẵn sàng..."
echo "============================================"
for i in $(seq 1 30); do
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
    -i ~/.ssh/techshop-key.pem ubuntu@"$VM_IP" "echo OK" 2>/dev/null; then
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
ansible-playbook playbooks/monitoring.yml \
  -e "monitoring_host=$VM_IP"

echo ""
echo "============================================"
echo " HOÀN THÀNH!"
echo " Prometheus:  http://$VM_IP:9090"
echo " Grafana:     http://$VM_IP:3000 (admin / xem vault.yml)"
echo " Node Exp:    http://$VM_IP:9100/metrics"
echo ""
echo " SSH:         ssh -i ~/.ssh/techshop-key.pem ubuntu@$VM_IP"
echo "============================================"
