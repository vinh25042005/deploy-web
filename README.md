

## 1. Kiến trúc tổng quan — Full Hạ tầng

### 1a. Sơ đồ hạ tầng AWS

```mermaid
flowchart TB
    subgraph Internet["🌐 Internet"]
        USER["👤 Người dùng"]
    end

    USER -->|"TCP 80/443"| NLB

    subgraph AWS["☁️ AWS ap-southeast-1 — VPC 10.0.0.0/16"]
        NLB["🔀 AWS NLB<br/>techshop-ingress-nlb.elb..."]
        
        subgraph PubA["🟢 Public Subnet A (AZ-a)"]
            ING1["🟢 Ingress Node 1<br/>t3.medium · Pub IP: 52.77.232.101<br/>CHỈ chạy: ingress-nginx"]
            RANCHER["🟢 Rancher Server<br/>t3.medium · Docker"]
        end

        subgraph PubB["🟢 Public Subnet B (AZ-b)"]
            ING2["🟢 Ingress Node 2<br/>t3.medium · Pub IP: 13.215.253.12<br/>CHỈ chạy: ingress-nginx"]
        end

        subgraph Priv["🔒 Private Subnets (AZ-a + AZ-b)"]
            CP1["🔒 Control-Plane 1<br/>t3.medium · etcd"]
            CP2["🔒 Control-Plane 2<br/>t3.medium · etcd"]
            CP3["🔒 Control-Plane 3<br/>t3.medium · etcd"]
        end
        
        NLB -->|"Health Check TCP:80"| ING1
        NLB -->|"Health Check TCP:80"| ING2
        
        ING1 -->|"hostNetwork: true<br/>bind :80, :443"| K8S
        ING2 -->|"hostNetwork: true<br/>bind :80, :443"| K8S
    end

    subgraph K8S["K8s Cluster (kubeadm v1.32) — namespace: techshop"]
        direction TB
        NGINX["🔀 NGINX Ingress Controller<br/>DaemonSet ×5 (hostNetwork)<br/>Route theo Host header"]
        FE["🖥️ Frontend ×2-5<br/>Next.js :3001"]
        BE["⚙️ Backend ×2-5<br/>Express + Prisma :3000"]
        PG["🗄️ Postgres ×1<br/>PostgreSQL :5432"]
        PROM["📊 Prometheus + Grafana<br/>+ Alertmanager"]
        CERT["🔒 cert-manager<br/>ClusterIssuer + Certificate"]
        CSI["💾 EBS CSI Driver<br/>Provision EBS volumes"]
        PVC["💾 PVC 10Gi · gp2"]
    end

    NGINX -->|"Host: techshop.local"| FE
    NGINX -->|"Host: grafana.techshop.local"| PROM
    FE -->|"/api/* → http://backend:3000"| BE
    BE --> PG
    PG --> PVC
    CSI --> PVC
    CERT --> NGINX
```

> **Phân bố node:** 2 Ingress Node (Public Subnet) chỉ chạy ingress-nginx, nhận traffic từ NLB. 3 Control-Plane Node (Private Subnet) chạy TOÀN BỘ ứng dụng (backend, frontend, postgres, prometheus, grafana, cert-manager...). Ra internet qua NAT Gateway.

### 1b. Luồng request chi tiết

```mermaid
sequenceDiagram
    participant Browser as 👤 Browser
    participant NLB as 🔀 AWS NLB
    participant Ingress as 🟢 Ingress Node (ingress-nginx)
    participant Frontend as 🖥️ Frontend Pod
    participant Backend as ⚙️ Backend Pod
    participant Postgres as 🗄️ Postgres
    participant EBS as 💾 EBS Volume

    Browser->>NLB: GET https://techshop.local/api/products
    NLB->>Ingress: TCP forward (Health Check OK)
    Ingress->>Ingress: TLS terminate + Host header routing
    Ingress->>Frontend: Proxy /api/* → backend:3000
    Frontend->>Backend: HTTP /api/products
    Backend->>Postgres: SELECT * FROM products
    Postgres->>EBS: Read data
    EBS-->>Postgres: Data
    Postgres-->>Backend: Rows
    Backend-->>Frontend: JSON
    Frontend-->>Ingress: HTML/JSON
    Ingress-->>NLB: Response
    NLB-->>Browser: HTTPS Response
```

### 1c. CI/CD Pipeline

```mermaid
flowchart LR
    DEV["👨‍💻 Push main"] --> CI

    subgraph GHA["GitHub Actions"]
        CI["🔨 CI (ci.yml)<br/>Lint → Test → Build → Trivy → Syft → Cosign"]
        CD["🚀 Deploy (deploy-gke.yml)<br/>Cosign Verify → kubectl rollout"]
    end

    subgraph GHCR["📦 GitHub Container Registry"]
        IMG_BE["backend:sha-abc123<br/>backend:latest"]
        IMG_FE["frontend:sha-abc123<br/>frontend:latest"]
    end

    CI -->|"Build + Push tag SHA"| IMG_BE
    CI -->|"Build + Push tag SHA"| IMG_FE
    CI -->|"SBOM + Cosign Sign"| ATTEST["🔏 Cosign Attestation"]
    CI --> CD
    CD -->|"Verify signature"| ATTEST
    CD -->|"kubectl set image :sha-XXX"| K8S["☸️ K8s Cluster"]
    K8S -->|"imagePullPolicy: Always"| IMG_BE
    K8S -->|"imagePullPolicy: Always"| IMG_FE
```

> **Dùng SHA tag thay vì latest:** Mỗi commit → 1 tag immutable `sha-<git hash>`. Deploy dùng SHA tag → không bị race condition khi 2 CI chạy gần nhau.

### 1d. Monitoring Stack

```mermaid
flowchart TB
    subgraph K8S["K8s Cluster — namespace: techshop"]
        METRICS["📊 Metrics Sources"]
        NE["Node Exporter<br/>DaemonSet :9100"]
        KSM["kube-state-metrics<br/>Deployment :8080"]
        MS["Metrics Server<br/>Deployment :443"]

        PROM["🔥 Prometheus<br/>StatefulSet :9090"]
        AM["🚨 Alertmanager<br/>StatefulSet :9093"]
        GRAFANA["📈 Grafana<br/>Deployment :80"]

        METRICS --> PROM
        NE --> PROM
        KSM --> PROM
        PROM --> GRAFANA
        PROM --> AM
        MS --> HPA["⚡ HPA<br/>Backend + Frontend<br/>min2 · max5 · CPU 50%"]
    end

    PROM -->|"PodRestartHigh Alert"| AM
```

### 1e. Kiến trúc Node (Phân bổ Pod)

```
┌─────────────────────────────────────────────────────────────┐
│                    5 EC2 t3.medium                           │
│                                                              │
│  ┌──────────────────────┐  ┌──────────────────────────────┐ │
│  │  INGRESS NODES (2)   │  │  CONTROL-PLANE NODES (3)     │ │
│  │  Public Subnet        │  │  Private Subnet              │ │
│  │                       │  │                              │ │
│  │  ✅ ingress-nginx     │  │  ✅ backend ×2               │ │
│  │  ✅ ebs-csi-node      │  │  ✅ frontend ×3              │ │
│  │  ✅ node-exporter     │  │  ✅ postgres                 │ │
│  │                       │  │  ✅ prometheus               │ │
│  │  ❌ KHÔNG chạy app    │  │  ✅ grafana                  │ │
│  │     (taint: ingress)  │  │  ✅ alertmanager             │ │
│  │                       │  │  ✅ cert-manager             │ │
│  │  Nhận traffic từ NLB  │  │  ✅ etcd (3 replicas)        │ │
│  └──────────────────────┘  └──────────────────────────────┘ │
│                                                              │
│  ┌──────────────────────┐                                    │
│  │  RANCHER (1)         │                                    │
│  │  Public Subnet        │                                    │
│  │  Docker standalone    │                                    │
│  └──────────────────────┘                                    │
└─────────────────────────────────────────────────────────────┘
```

### 1f. Luồng Backup/Restore

```mermaid
flowchart LR
    PG["🗄️ Postgres Pod"] -->|"CronJob: 0 */6 * * *"| CRON["⏰ CronJob<br/>postgres-backup"]
    CRON -->|"pg_dump | gzip"| TMP["/tmp/backup.sql.gz"]
    TMP -->|"aws s3 cp"| S3["☁️ S3 Bucket<br/>techshop-loki-*"]
    
    S3 -->|"InitContainer<br/>restore-from-s3"| INIT["🔄 Init Container<br/>khi volume mới"]
    INIT -->|"gunzip | psql"| PG2["🗄️ Postgres Pod<br/>(fresh deploy)"]
```
---

## 2. Cấu trúc thư mục

```
deploy-web/
├── .github/workflows/
│   ├── ci.yml               # CI: Lint → Test → Build → Scan → SBOM → Sign
│   └── deploy-gke.yml       # CD: Verify signature → Deploy K8s
├── ansible/
│   ├── inventory.ini         # Tạo bởi Terraform (local_file)
│   ├── group_vars/all.yml    # k8s_version: "1.32", pod_cidr: "10.244.0.0/16"
│   ├── playbooks/k8s-cluster.yml
│   └── roles/
│       ├── common/tasks/   # containerd + kubeadm + kubectl + kubelet
│       ├── master/tasks/   # kubeadm init + Calico + upload SSM
│       └── worker/tasks/   # join cluster + label node
├── backend/
│   ├── Dockerfile           # Express + Prisma + TypeScript (multi-stage build)
│   ├── package.json
│   └── src/                 # controllers, middleware, services, routes
├── frontend/
│   ├── Dockerfile           # Next.js (multi-stage build)
│   ├── package.json
│   ├── next.config.js
│   └── src/app/api/[...path]/route.ts  # Proxy API → backend
├── database/
│   ├── seed.ts              # Dữ liệu mẫu
│   └── prisma/
│       ├── schema.prisma    # PostgreSQL schema
│       └── migrations/
├── helm/techshop/
│   ├── Chart.yaml           # 7 dependencies
│   ├── values.yaml          # Config mặc định
│   ├── env/                 # values-dev.yaml, values-stg.yaml, values-prd.yaml
│   └── templates/           # K8s manifests (xem bảng bên dưới)
├── terraform/
│   ├── live/
│   │   ├── main.tf          # Root module: network + compute + rancher
│   │   ├── variables.tf     # region, project_name, kubeconfig_path
│   │   └── outputs.tf       # ingress_public_ips, rancher_url
│   └── modules/
│       ├── network/         # VPC, 4 subnet, IGW, NAT, 3 SG
│       ├── compute/         # 5 EC2 + IAM + inventory.tpl
│       └── rancher/         # EC2 + Docker Rancher (user_data)
└── setup.sh                 # Tự động hóa toàn bộ
```

