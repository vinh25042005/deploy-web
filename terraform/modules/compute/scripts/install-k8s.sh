#!/bin/bash
# ============================================
# Startup Script: Cài Kubernetes bằng kubeadm
# Mô hình 3 master kiêm worker (HA Control Plane)
#
# node_type = "master-first": kubeadm init + upload cert key + join command lên GCS
# node_type = "master-join":  tải cert key từ GCS + kubeadm join --control-plane
#
# Biến từ Terraform: ${node_type}, ${pod_cidr}, ${k8s_version}, ${project_id}, ${region}, ${endpoint_ip}
# ============================================
set -e

echo "============================================"
echo "Node type: ${node_type}"
echo "K8s version: ${k8s_version}"
echo "Project: ${project_id}"
echo "============================================"

# Xoá bucket GCS cũ — chạy ngay từ đầu để tránh node-join đọc file cũ
if [ "${node_type}" = "master-first" ]; then
  BUCKET="${project_id}-k8s-tokens"
  gsutil rm -rf "gs://$BUCKET" 2>/dev/null || true
fi

# ═══════════════════════════════════════════
# STEP 1: Tắt swap (kubeadm bắt buộc)
# ═══════════════════════════════════════════
swapoff -a
sed -i '/swap/d' /etc/fstab

# ═══════════════════════════════════════════
# STEP 2: Cài containerd (container runtime)
# ═══════════════════════════════════════════
cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

apt-get update
apt-get install -y containerd

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

# ═══════════════════════════════════════════
# STEP 3: Cài kubeadm, kubelet, kubectl
# ═══════════════════════════════════════════
apt-get install -y apt-transport-https ca-certificates curl gpg

mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/Release.key | \
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/ /" | \
    tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# ═══════════════════════════════════════════
# STEP 4: master-first — Khởi tạo cluster + upload certs
# ═══════════════════════════════════════════
if [ "${node_type}" = "master-first" ]; then
  echo ">>> [MASTER-FIRST] Đang khởi tạo cluster (HA control plane)..."

  MY_IP=$(hostname -I | awk '{print $1}')
  echo ">>> [MASTER-FIRST] My IP: $MY_IP"

  # Lưu toàn bộ output của kubeadm init (chứa lệnh join cho control-plane)
  kubeadm init \
    --control-plane-endpoint=$MY_IP:6443 \
    --apiserver-advertise-address=$MY_IP \
    --pod-network-cidr=${pod_cidr} \
    --upload-certs \
    --kubernetes-version=v${k8s_version}.0 2>&1 | tee /tmp/kubeadm-init.log

  # Cấu hình kubectl
  mkdir -p $HOME/.kube
  cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config

  # Cài Calico CNI
  echo ">>> [MASTER-FIRST] Đang cài Calico CNI..."
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml

  # Untaint
  echo ">>> [MASTER-FIRST] Untaint master nodes..."
  kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true

  # Trích xuất lệnh join control-plane (nhiều dòng, kết thúc bởi dòng trống)
  # Đây là lệnh join đầu tiên trong output (có --control-plane --certificate-key)
  awk '/kubeadm join/{found=1} found{print} /^$/{if(found) exit}' /tmp/kubeadm-init.log | sed 's/^[[:space:]]*//' > /tmp/join-cp.sh

  # Lưu IP master
  echo "$MY_IP" > /tmp/master-ip.txt

  # Upload lên GCS
  gsutil mb -l ${region} "gs://$BUCKET" 2>/dev/null || true
  gsutil cp /tmp/join-cp.sh "gs://$BUCKET/join-cp.sh"
  gsutil cp /tmp/master-ip.txt "gs://$BUCKET/master-ip.txt"

  echo ">>> [MASTER-FIRST] Đã upload lệnh join control-plane lên gs://$BUCKET/"
  echo ">>> [MASTER-FIRST] Hoàn tất!"
fi

# ═══════════════════════════════════════════
# STEP 5: master-join — Join control-plane (Node 2 & 3)
# ═══════════════════════════════════════════
if [ "${node_type}" = "master-join" ]; then
  echo ">>> [MASTER-JOIN] Đợi 5 phút cho master-first hoàn tất..."
  sleep 300  # Đảm bảo master-first xoá bucket cũ + upload file mới
  echo ">>> [MASTER-JOIN] Bắt đầu tìm lệnh join..."

  BUCKET="${project_id}-k8s-tokens"

  for i in $(seq 1 60); do
    if gsutil ls "gs://$BUCKET/join-cp.sh" &>/dev/null; then

      echo ">>> [MASTER-JOIN] Đã tìm thấy lệnh join control-plane!"
      gsutil cp "gs://$BUCKET/join-cp.sh" /tmp/join-cp.sh
      chmod +x /tmp/join-cp.sh

      # Sửa endpoint trong lệnh join (thay IP trong lệnh bằng IP master)
      MASTER_IP=$(gsutil cat "gs://$BUCKET/master-ip.txt" | tr -d '\n')
      MY_IP=$(hostname -I | awk '{print $1}')

      # Thêm --apiserver-advertise-address vào lệnh join
      bash /tmp/join-cp.sh --apiserver-advertise-address=$MY_IP

      mkdir -p $HOME/.kube
      cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
      chown $(id -u):$(id -g) $HOME/.kube/config

      echo ">>> [MASTER-JOIN] Join control-plane thành công!"
      exit 0
    fi
    echo ">>> [MASTER-JOIN] Chưa thấy lệnh join... thử lại lần $i/60"
    sleep 10
  done

  echo ">>> [MASTER-JOIN] LỖI: Không tìm thấy lệnh join sau 10 phút!"
  exit 1
fi

echo "============================================"
echo ">>> Script install-k8s.sh hoàn tất!"
echo "============================================"