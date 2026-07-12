# `install-k8s-aws.sh` — Giải thích chi tiết từng lệnh

## Tổng quan

Script này chạy tự động khi EC2 boot lần đầu (user_data). Nó cài đặt K8s cluster 3 node HA control-plane (stacked etcd) trên AWS, dùng SSM Parameter Store để tự động join cluster.

Terraform truyền 3 biến vào script qua `templatefile()`:
- `${node_type}`: `master-first` (node-1) hoặc `master-join` (node-2,3)
- `${pod_cidr}`: dải IP cho Pod network (VD: `10.244.0.0/16`)
- `${k8s_version}`: phiên bản Kubernetes (VD: `1.35`)

---

## STEP 0: Đợi NAT Gateway sẵn sàng

```bash
for i in $(seq 1 30); do
  if curl -s --connect-timeout 3 http://archive.ubuntu.com > /dev/null 2>&1; then
    echo ">>> Internet OK!"
    break
  fi
  sleep 10
done
```

**Giải thích:** EC2 trong private subnet cần NAT Gateway để ra internet tải packages. NAT Gateway mất ~2 phút để provision. Vòng lặp kiểm tra `curl` tới `archive.ubuntu.com`, thử tối đa 30 lần × 10s = 5 phút. Nếu không có bước này, `apt-get update` sẽ fail vì không có internet.

---

## STEP 1: Tắt swap

```bash
swapoff -a                    # Tắt swap ngay lập tức
sed -i '/swap/d' /etc/fstab   # Xóa dòng swap khỏi fstab → không tự bật lại sau reboot
```

**Giải thích:** Kubelet yêu cầu tắt swap để đảm bảo hiệu năng và quản lý memory chính xác. Nếu swap còn bật, kubelet sẽ không start.

---

## STEP 2: Cài containerd (container runtime)

### 2a. Load kernel modules

```bash
cat <<EOF > /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter
```

- **`overlay`**: Kernel module cho overlay filesystem — containerd dùng để tạo lớp filesystem cho container image.
- **`br_netfilter`**: Kernel module cho bridge network filter — cho phép iptables rule hoạt động trên traffic đi qua Linux bridge (dùng trong Pod-to-Pod communication).

### 2b. Cấu hình sysctl

```bash
cat <<EOF > /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-ip6tables=1
EOF
sysctl --system
```

- **`bridge-nf-call-iptables=1`**: Bắt buộc iptables xử lý traffic qua bridge (cần cho kube-proxy và NetworkPolicy).
- **`ip_forward=1`**: Cho phép node forward IP packets giữa các Pod (routing giữa các interface mạng).
- **`sysctl --system`**: Load tất cả sysctl config từ `/etc/sysctl.d/`.

### 2c. Cài containerd

```bash
apt-get update -qq
apt-get install -y -qq containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd && systemctl enable containerd
```

- **`containerd config default`**: Sinh file config mặc định.
- **`SystemdCgroup = true`**: Quan trọng! Dùng systemd cgroup driver thay vì cgroupfs. Nếu không set, kubelet (cũng dùng systemd) và containerd sẽ dùng 2 cgroup driver khác nhau → node không ổn định.
- **`systemctl enable containerd`**: Tự động start containerd khi boot.

---

## STEP 3: Cài kubeadm, kubelet, kubectl

```bash
apt-get install -y -qq apt-transport-https ca-certificates curl gpg
mkdir -p /etc/apt/keyrings

# Thêm Kubernetes APT repository + GPG key
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update -qq
apt-get install -y -qq kubelet kubeadm kubectl awscli
apt-mark hold kubelet kubeadm kubectl
```

- **`gpg --dearmor`**: Giải mã GPG key từ ASCII-armored sang binary để apt verify package signature.
- **`apt-mark hold`**: Khóa phiên bản kubelet/kubeadm/kubectl — tránh `apt upgrade` vô tình nâng cấp gây mismatch version trong cluster.
- **`awscli`**: Cần cho việc đọc/ghi SSM Parameter Store (join command + kubeconfig).

---

## Lấy region từ metadata

```bash
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
```

**Giải thích:** `169.254.169.254` là EC2 metadata endpoint nội bộ. Trả về region hiện tại (VD: `ap-southeast-1`) không cần hardcode.

---

## Nhánh `master-first` (chạy trên node-1)

### Kubeadm init

```bash
MY_IP=$(hostname -I | awk '{print $1}')

kubeadm init \
  --control-plane-endpoint=$MY_IP:6443 \
  --apiserver-advertise-address=$MY_IP \
  --pod-network-cidr=${pod_cidr} \
  --upload-certs \
  --kubernetes-version=v${k8s_version}.0
```

- **`--control-plane-endpoint`**: Địa chỉ IP:port mà các node khác dùng để join cluster. Ở đây dùng private IP của node-1.
- **`--apiserver-advertise-address`**: IP mà API Server lắng nghe.
- **`--pod-network-cidr`**: Dải IP cấp cho Pod (Calico sẽ dùng dải này).
- **`--upload-certs`**: Tự động upload certificate lên cluster dạng Secret → các control-plane node khác không cần copy cert thủ công.
- **`--kubernetes-version`**: Chỉ định chính xác version.

### Cấu hình kubectl

```bash
mkdir -p $HOME/.kube
cp /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

Copy kubeconfig cho user `ubuntu` để dùng `kubectl`.

### Cài Calico CNI

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
```

**Giải thích:** Calico là Container Network Interface (CNI) plugin, chịu trách nhiệm:
- Cấp IP cho mỗi Pod từ dải `pod_cidr`
- Routing giữa các Pod trên các node khác nhau
- NetworkPolicy enforcement

### Untaint control-plane

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true
```

**Giải thích:** Mặc định control-plane node có taint `NoSchedule` → Pod thường không được schedule lên. Untaint để Pod có thể chạy trên mọi node (phù hợp cluster nhỏ 3 node).

### Upload join command lên SSM

```bash
JOIN_CMD=$(kubeadm token create --print-join-command)
CERT_KEY=$(kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1)
FULL_JOIN="$JOIN_CMD --control-plane --certificate-key $CERT_KEY"

aws ssm put-parameter --name "/k8s/join-command" \
  --value "$FULL_JOIN" --type String --overwrite --region $REGION
```

- **`kubeadm token create --print-join-command`**: Tạo token + in ra lệnh join cơ bản.
- **`--certificate-key`**: Key giải mã certificate đã upload lên cluster (từ `--upload-certs` trước đó). Cần để join control-plane node mới.
- **`aws ssm put-parameter`**: Lưu full join command vào SSM Parameter Store (`/k8s/join-command`) để node-2,3 tự động đọc.

### Upload kubeconfig lên SSM

```bash
KUBECONFIG_B64=$(cat /etc/kubernetes/admin.conf | gzip | base64 -w0)
aws ssm put-parameter --name "/k8s/kubeconfig" \
  --value "$KUBECONFIG_B64" --type String --overwrite --region $REGION
```

- **`gzip | base64 -w0`**: Nén + encode kubeconfig (~5.6KB) thành chuỗi base64 để vừa giới hạn 4KB của SSM Standard tier. Terraform sẽ đọc parameter này để cấu hình Kubernetes provider.

---

## Nhánh `master-join` (chạy trên node-2, node-3)

```bash
while [ $RETRY -lt 12 ]; do
  JOIN_CMD=$(aws ssm get-parameter --name "/k8s/join-command" \
    --query Parameter.Value --output text --region $REGION 2>/dev/null)
  if [ -n "$JOIN_CMD" ] && [ "$JOIN_CMD" != "None" ]; then
    sudo $JOIN_CMD
    ...
  fi
  sleep 10
  RETRY=$((RETRY+1))
done
```

**Giải thích:**
1. Poll SSM Parameter `/k8s/join-command` mỗi 10 giây, tối đa 12 lần (2 phút).
2. Khi nhận được join command → thực thi để join cluster với role control-plane.
3. Certificate tự động được giải mã nhờ `--certificate-key` đã có trong join command.
4. Sau khi join, etcd tự động sync dữ liệu từ node-1 → hình thành HA cluster 3 node.

---

## Kiến trúc cluster sau khi hoàn tất

```
Node-1 (10.20.10.x, AZ a, master-first)
├── API Server + etcd + Scheduler + Controller Manager
├── kubelet + kube-proxy + Calico
└── containerd

Node-2 (10.20.10.x, AZ a, master-join)
├── API Server + etcd + Scheduler + Controller Manager
├── kubelet + kube-proxy + Calico
└── containerd

Node-3 (10.20.20.x, AZ b, master-join)
├── API Server + etcd + Scheduler + Controller Manager
├── kubelet + kube-proxy + Calico
└── containerd

SSM Parameter Store:
├── /k8s/join-command    ← lệnh kubeadm join (node-2,3 dùng để join)
└── /k8s/kubeconfig      ← admin.conf (Terraform dùng để config provider)
```

---

## Luồng cài đặt 

| Step | Làm gì? | Tại sao cần? |
|---|---|---|
| **1. Tắt swap** | `swapoff -a` và xóa khỏi `/etc/fstab` | kubeadm **bắt buộc** swap phải tắt. Nếu còn swap, kubelet sẽ từ chối chạy. Lý do: K8s cần kiểm soát chính xác RAM, swap làm sai lệch metric |
| **2. Cài containerd** | Container runtime | K8s không chạy container trực tiếp. Nó ra lệnh cho containerd (hoặc CRI-O). Đây là thứ duy nhất thực sự `docker pull` + `docker run` |
| **2a. `SystemdCgroup = true`** | Sửa config containerd | Mặc định containerd dùng `cgroupfs`. Kubelet dùng `systemd`. Nếu không khớp → kubelet không kiểm soát được tài nguyên container → lỗi |
| **2b. Kernel modules** | `overlay`, `br_netfilter` | `overlay`: cho phép Docker/containerd dùng overlay filesystem (image layer). `br_netfilter`: cho phép iptables hoạt động trên bridge network (cần cho Pod-to-Pod communication) |
| **2c. Sysctl** | `bridge-nf-call-iptables`, `ip_forward` | Nếu không bật → gói tin giữa các Pod bị drop bởi iptables → Pod không nói chuyện được với nhau |
| **3. Cài kubeadm/kubelet/kubectl** | Bộ 3 công cụ K8s | `kubeadm`: khởi tạo cluster (chỉ chạy 1 lần). `kubelet`: chạy nền trên mọi node, nhận lệnh từ API server. `kubectl`: công cụ dòng lệnh để điều khiển cluster |
| **3a. `apt-mark hold`** | Khóa phiên bản | Ngăn `apt upgrade` tự động nâng cấp kubeadm/kubelet/kubectl → tránh version mismatch gây sập cluster |
| **4. `kubeadm init` (master)** | Khởi tạo control plane | Tự động: tạo chứng chỉ TLS → chạy API server → chạy etcd → chạy scheduler → chạy controller manager. `--pod-network-cidr=10.244.0.0/16` phải khớp với Calico |
| **4a. Cài Calico CNI** | Pod network plugin | Để Pod trên worker-A nói chuyện được với Pod trên worker-B. Calico tạo 1 mạng overlay ảo trên nền VPC. Không có CNI → Pod bị stuck ở trạng thái `Pending` mãi |
| **4b. Upload join command lên GCS** | `gs://<project>-k8s-tokens/join-command.sh` | Worker ở private subnet không SSH vào master được. GCS bucket là "hòm thư chung" để master thả join command, worker đến lấy |
| **5. `kubeadm join` (worker)** | Gia nhập cluster | Worker tải join command từ GCS → chạy → tự đăng ký với API server. Sau đó kubelet trên worker bắt đầu nhận lệnh từ master |

---

## Tự động join 

```
Master VM khởi động:
  1. kubeadm init → cluster sẵn sàng
  2. kubeadm token create --print-join-command > /tmp/join-command.sh
  3. gsutil cp /tmp/join-command.sh gs://<project>-k8s-tokens/join-command.sh
     ↓
Worker VM khởi động (cùng lúc hoặc sau):
  1. Cài containerd + kubeadm
  2. Vòng lặp: gsutil ls gs://<project>-k8s-tokens/join-command.sh
     ├── Chưa thấy → đợi 10s, thử lại (tối đa 30 lần = 5 phút)
     └── Thấy rồi → tải về → bash join-command.sh → JOIN!
```

---

## Biến truyền từ Terraform

| Biến | Mô tả | Ví dụ |
|---|---|---|
| `${node_type}` | `master` hoặc `worker` | `master` |
| `${pod_cidr}` | Dải IP cho Pod network | `10.244.0.0/16` |
| `${k8s_version}` | Phiên bản Kubernetes | `1.35` |
| `${project_id}` | GCP Project ID (dùng đặt tên GCS bucket) | `techshop-prod-2026` |
| `${region}` | GCP region (nơi tạo GCS bucket) | `asia-southeast1` |

---

