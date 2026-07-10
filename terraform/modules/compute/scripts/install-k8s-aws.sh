#!/bin/bash
echo "============================================"
echo "Node: ${node_type} | K8s: ${k8s_version}"
echo "============================================"

# STEP 0: Đợi NAT Gateway sẵn sàng (private subnet cần NAT để ra internet)
echo ">>> Kiểm tra internet..."
for i in $(seq 1 30); do
  if curl -s --connect-timeout 3 http://archive.ubuntu.com > /dev/null 2>&1; then
    echo ">>> Internet OK!"
    break
  fi
  echo ">>> Đợi NAT Gateway... ($i/30)"
  sleep 10
done

# STEP 1: Tắt swap
swapoff -a
sed -i '/swap/d' /etc/fstab

# STEP 2: Cài containerd
cat <<EOF > /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
modprobe overlay; modprobe br_netfilter
cat <<EOF > /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-ip6tables=1
EOF
sysctl --system
apt-get update -qq
apt-get install -y -qq containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd && systemctl enable containerd

# STEP 3: Cài kubeadm + kubectl + kubelet
apt-get install -y -qq apt-transport-https ca-certificates curl gpg
mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
apt-get update -qq
apt-get install -y -qq kubelet kubeadm kubectl awscli
apt-mark hold kubelet kubeadm kubectl

REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# ═══ MASTER-FIRST: Init + upload join command lên SSM ═══
if [ "${node_type}" = "master-first" ]; then
  MY_IP=$(hostname -I | awk '{print $1}')
  echo ">>> [MASTER-FIRST] IP: $MY_IP"

  # Xóa join command cũ TRƯỚC KHI init (tránh node-2,3 lấy phải IP cũ)
  aws ssm delete-parameter --name "/k8s/join-command" --region $REGION 2>/dev/null || true

  kubeadm init \
    --control-plane-endpoint=$MY_IP:6443 \
    --apiserver-advertise-address=$MY_IP \
    --pod-network-cidr=${pod_cidr} \
    --upload-certs \
    --kubernetes-version=v${k8s_version}.0 2>&1 | tee /tmp/kubeadm-init.log

  mkdir -p $HOME/.kube
  cp /etc/kubernetes/admin.conf $HOME/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config

  echo ">>> [MASTER-FIRST] Cài Calico..."
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml

  echo ">>> [MASTER-FIRST] Untaint..."
  kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true

  # Upload join command lên SSM Parameter Store
  JOIN_CMD=$(kubeadm token create --print-join-command)
  CERT_KEY=$(kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1)
  FULL_JOIN="$JOIN_CMD --control-plane --certificate-key $CERT_KEY"

  echo ">>> [MASTER-FIRST] Upload join command to SSM..."
  aws ssm put-parameter --name "/k8s/join-command" --value "$FULL_JOIN" \
    --type String --overwrite --region $REGION

  # Lưu kubeconfig lên SSM Parameter Store (gzip+base64 để vừa 4KB)
  KUBECONFIG_B64=$(cat /etc/kubernetes/admin.conf | gzip | base64 -w0)
  aws ssm put-parameter --name "/k8s/kubeconfig" --value "$KUBECONFIG_B64" \
    --type String --overwrite --region $REGION

  echo ">>> [MASTER-FIRST] Hoàn tất! Node-2,3 sẽ tự join."
fi

# ═══ MASTER-JOIN: Tự động đọc join command từ SSM ═══
if [ "${node_type}" = "master-join" ]; then
  echo ">>> [MASTER-JOIN] Đợi join command từ master-first..."

  # Chờ tối đa 10 phút, retry nếu fail
  RETRY=0
  while [ $RETRY -lt 12 ]; do
    JOIN_CMD=$(aws ssm get-parameter --name "/k8s/join-command" \
      --query Parameter.Value --output text --region $REGION 2>/dev/null)
    if [ -n "$JOIN_CMD" ] && [ "$JOIN_CMD" != "None" ]; then
      echo ">>> [MASTER-JOIN] Đã nhận join command!"
      sudo $JOIN_CMD > /tmp/join.log 2>&1
      if [ $? -eq 0 ]; then
        echo ">>> [MASTER-JOIN] Join thành công!"
        exit 0
      fi
      echo ">>> [MASTER-JOIN] Join thất bại, retry... (lần $((RETRY+1))/12)"
      cat /tmp/join.log | tail -5
    else
      echo ">>> [MASTER-JOIN] Đợi join command... (lần $((RETRY+1))/12)"
    fi
    sleep 10
    RETRY=$((RETRY+1))
  done

  echo "!!! [MASTER-JOIN] Hết thời gian chờ. Join thủ công!"
fi

echo "============================================"
echo ">>> Script hoàn tất!"
echo "============================================"
