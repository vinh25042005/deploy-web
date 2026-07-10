# `install-k8s.sh` — Giải thích chi tiết

## Tổng quan

Script này chạy **tự động khi VM khởi động lần đầu** (startup script). Nó cài đặt toàn bộ Kubernetes cluster: 1 master + 2 worker. Dùng chung 1 script cho cả master và worker, phân biệt bằng biến `${node_type}` do Terraform truyền vào.

---

## Kiến trúc cluster sau khi cài

```
k8s-master (public subnet, có IP công khai)
├── API Server      ← "Lễ tân": mọi lệnh kubectl đều qua đây
├── etcd            ← "Trí nhớ": database lưu trạng thái toàn cluster
├── Scheduler       ← "Xếp chỗ": quyết định Pod chạy ở worker nào
├── Controller Mgr  ← "Giám sát": đảm bảo "thực tế = mong muốn"
├── kubelet         ← "Lính gác": nhận lệnh từ master, báo cáo trạng thái
├── kube-proxy      ← "Đưa thư": điều phối network giữa các Pod
└── containerd      ← "Động cơ": thực sự chạy container

k8s-worker-a (private subnet, KHÔNG IP công khai)
├── kubelet
├── kube-proxy
└── containerd

k8s-worker-b (private subnet, KHÔNG IP công khai)
├── kubelet
├── kube-proxy
└── containerd
```

---

## Luồng cài đặt từng bước

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

## Cơ chế tự động join (không SSH, không thủ công)

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

## Lỗi thường gặp & cách debug

| Lỗi | Nguyên nhân | Cách sửa |
|---|---|---|
| `kubelet failed to start` | Swap chưa tắt | `swapoff -a` + kiểm tra `/etc/fstab` |
| `container runtime is not running` | containerd chưa chạy hoặc sai `SystemdCgroup` | `systemctl status containerd` + kiểm tra `/etc/containerd/config.toml` |
| Pod stuck `Pending` mãi | Chưa cài CNI (Calico) | `kubectl apply -f calico.yaml` |
| Worker không join được | GCS bucket không tồn tại hoặc worker không có quyền đọc | Kiểm tra IAM: worker VM cần `storage.objectViewer` |
| `kubeadm init` báo version không tồn tại | Phiên bản K8s chưa có trong repo | Kiểm tra `https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/` |
| `cgroupfs` vs `systemd` mismatch | containerd mặc định dùng cgroupfs, kubelet dùng systemd | `sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml` |

---

## Cách kiểm tra cluster sau khi cài

```bash
# SSH vào master
ssh deploy@<master-public-ip>

# Kiểm tra node đã join chưa
kubectl get nodes -o wide

# Kết quả mong đợi:
# NAME                          STATUS   ROLES           AGE   INTERNAL-IP
# techshop-prod-2026-k8s-master Ready    control-plane   5m    10.20.1.x
# techshop-prod-2026-k8s-worker-a Ready  <none>          3m    10.20.10.x
# techshop-prod-2026-k8s-worker-b Ready  <none>          3m    10.20.20.x

# Kiểm tra tất cả pod hệ thống
kubectl get pods -A
```
