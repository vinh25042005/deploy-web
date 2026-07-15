# 📊 Resource Map — Full Code Reference

> Mỗi resource K8s + AWS map đến **đoạn code cụ thể** tạo ra nó.  
> **Release:** `techshop-dev` | **Namespace:** `techshop`

---

## 1. TERRAFORM — AWS Infrastructure

### 1.1. EC2 Instances (5 nodes)
**File:** `terraform/modules/compute/main.tf` dòng 71-85
```hcl
resource "aws_instance" "node" {
  count                  = var.node_count    # 5 nodes
  ami                    = data.aws_ami.ubuntu.id
  iam_instance_profile   = aws_iam_instance_profile.node_ssm.name
  instance_type          = var.instance_type # t3.medium
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = var.sg_ids
  key_name               = var.key_name
  # ... user_data, tags, root_block_device
}
```
→ 5 EC2 instances (`t3.medium`) trong private subnets

### 1.2. IAM Role (S3 + SSM + EBS permissions)
**File:** `terraform/modules/compute/main.tf` dòng 13-65
```hcl
resource "aws_iam_role" "node_ssm" {
  name = "${var.project_name}-node-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}
resource "aws_iam_role_policy" "node_ssm_params" {
  policy = jsonencode({
    Statement = [
      # Cho phép upload/download kubeconfig từ SSM
      { Effect = "Allow", Action = ["ssm:PutParameter","ssm:GetParameter",...],
        Resource = "arn:aws:ssm:...:parameter/k8s/*" },
      # Cho phép EBS CSI driver attach/detach volumes
      { Effect = "Allow", Action = ["ec2:CreateVolume","ec2:AttachVolume",...],
        Resource = "*" },
      # Cho phép backup/restore từ S3 bucket
      { Effect = "Allow", Action = ["s3:ListBucket","s3:GetObject","s3:PutObject",...],
        Resource = ["arn:aws:s3:::techshop-loki-*"] }
    ]
  })
}
```
→ EC2 nodes có quyền: SSM, EBS, S3

### 1.3. VPC + Subnets + Gateways
**File:** `terraform/modules/network/main.tf`
```hcl
resource "aws_vpc" "main" { cidr_block = "10.0.0.0/16" }
resource "aws_subnet" "public"  { count = 3; cidr_block = "10.0.${count.index+1}.0/24" }
resource "aws_subnet" "private" { count = 3; cidr_block = "10.0.${count.index+10}.0/24" }
resource "aws_internet_gateway" "main" { vpc_id = aws_vpc.main.id }
resource "aws_nat_gateway" "main" { allocation_id = aws_eip.nat.id; subnet_id = aws_subnet.public[0].id }
resource "aws_route_table" "public"  { route { cidr_block = "0.0.0.0/0"; gateway_id = aws_internet_gateway.main.id } }
resource "aws_route_table" "private" { route { cidr_block = "0.0.0.0/0"; nat_gateway_id = aws_nat_gateway.main.id } }
```
→ VPC 10.0.0.0/16, 3 public + 3 private subnets, IGW + NAT

### 1.4. S3 Bucket + DynamoDB Lock
**File:** `terraform/live/main.tf`
```hcl
terraform {
  backend "s3" {
    bucket         = "techshop-tfstate-2026"
    key            = "terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "techshop-tf-lock"
  }
}
resource "aws_s3_bucket" "loki" { bucket = "techshop-loki-790400775134" }
resource "aws_dynamodb_table" "tf_lock" { name = "techshop-tf-lock"; hash_key = "LockID"; billing_mode = "PAY_PER_REQUEST" }
```

### 1.5. Rancher Server (EC2)
**File:** `terraform/modules/rancher/main.tf`
```hcl
resource "aws_instance" "rancher" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  user_data     = templatefile("${path.module}/user_data.sh", {...})  # docker run rancher
}
```

---

## 2. ANSIBLE — Kubernetes Cluster Bootstrap

### 2.1. Containerd + Kubeadm Install (ALL nodes)
**File:** `ansible/roles/common/tasks/main.yml`
```yaml
- name: Install containerd
  apt: name=containerd state=present
- name: Install kubeadm, kubelet, kubectl
  apt: name={{ item }} state=present
  loop: [kubeadm, kubelet, kubectl]
- name: Hold k8s packages
  shell: apt-mark hold kubeadm kubelet kubectl
```
→ Cài container runtime + k8s tools trên tất cả 5 nodes

### 2.2. kubeadm init (Master Node)
**File:** `ansible/roles/master/tasks/main.yml` dòng 34-43
```yaml
- name: Run kubeadm init
  shell: |
    kubeadm init \
      --control-plane-endpoint={{ master_private_ip }}:6443 \
      --apiserver-advertise-address={{ master_private_ip }} \
      --apiserver-cert-extra-sans={{ master_public_ip }} \
      --pod-network-cidr=10.244.0.0/16 \
      --upload-certs \
      --kubernetes-version=v1.32.0
```
→ Khởi tạo control-plane, tạo `/etc/kubernetes/admin.conf`

### 2.3. Calico CNI + Untaint Master
**File:** `ansible/roles/master/tasks/main.yml` dòng 54-60
```yaml
- name: Install Calico CNI
  shell: kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml

- name: Untaint master nodes
  shell: kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true
```
→ Network plugin + cho phép schedule pod trên master

### 2.4. Join Workers
**File:** `ansible/roles/worker/tasks/main.yml`
```yaml
- name: Join worker to cluster
  shell: "{{ hostvars['master']['join_cmd'] }}"
```

### 2.5. Upload kubeconfig to SSM
**File:** `ansible/roles/master/tasks/main.yml` dòng 72-80
```yaml
- name: Upload kubeconfig to SSM
  shell: |
    KUBECONFIG_B64=$(gzip -c $HOME/.kube/config | base64 -w0)
    aws ssm put-parameter --name /k8s/kubeconfig --type String \
      --value "$KUBECONFIG_B64" --region {{ aws_region.stdout }} --overwrite
```
→ Kubeconfig lưu vào SSM Parameter Store `/k8s/kubeconfig`

---

## 3. HELM TEMPLATES — Ứng Dụng

### 3.1. Backend (Deployment + Service)
**File:** `helm/techshop/templates/backend.yaml` — TOÀN BỘ
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: {{ .Values.namespace }}
  labels: { app: backend }
spec:
  replicas: {{ .Values.backend.replicas }}   # 2
  selector:
    matchLabels: { app: backend }
  template:
    metadata:
      labels: { app: backend }
    spec:
      containers:
        - name: backend
          image: {{ .Values.images.backend }}   # ghcr.io/vinh25042005/deploy-web/backend:latest
          imagePullPolicy: Always
          ports:
            - containerPort: {{ .Values.backend.port }}  # 3000
          envFrom:
            - configMapRef: { name: backend-config }
            - secretRef: { name: backend-secrets }
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: {{ .Values.namespace }}
spec:
  ports:
    - port: {{ .Values.backend.port }}
      targetPort: {{ .Values.backend.port }}
  selector: { app: backend }
  type: ClusterIP
```
→ Tạo: `deployment/backend` (2 replicas) + `service/backend` (ClusterIP:3000)

### 3.2. Frontend (Deployment + Service)
**File:** `helm/techshop/templates/frontend.yaml` — TOÀN BỘ
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: {{ .Values.namespace }}
  labels: { app: frontend }
spec:
  replicas: {{ .Values.frontend.replicas }}   # 2
  selector:
    matchLabels: { app: frontend }
  template:
    metadata:
      labels: { app: frontend }
    spec:
      containers:
        - name: frontend
          image: {{ .Values.images.frontend }}  # ghcr.io/vinh25042005/deploy-web/frontend:latest
          imagePullPolicy: Always
          ports:
            - containerPort: {{ .Values.frontend.port }}  # 3001
          envFrom:
            - configMapRef: { name: frontend-config }
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: {{ .Values.namespace }}
spec:
  ports:
    - port: {{ .Values.frontend.port }}
      targetPort: {{ .Values.frontend.port }}
  selector: { app: frontend }
  type: ClusterIP
```
→ Tạo: `deployment/frontend` (2 replicas) + `service/frontend` (ClusterIP:3001)

### 3.3. Postgres (Deployment + Service + PVC + InitContainer)
**File:** `helm/techshop/templates/postgres.yaml` — TOÀN BỘ
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: {{ .Values.namespace }}
  labels: { app: postgres }
spec:
  replicas: 1
  selector:
    matchLabels: { app: postgres }
  template:
    metadata:
      labels: { app: postgres }
    spec:
      # ▼ INIT CONTAINER: tự restore từ S3 nếu volume mới
      initContainers:
      - name: restore-from-s3
        image: amazon/aws-cli:latest
        env:
        - name: S3_BUCKET
          value: {{ .Values.postgres.backup.s3Bucket | quote }}
        command:
        - /bin/sh
        - -c
        - |
          if [ -f /var/lib/postgresql/PG_VERSION ]; then
            echo "Database exists, skipping restore"
          else
            LATEST=$(aws s3 ls s3://$S3_BUCKET/ | grep '.sql.gz' | sort | tail -1 | awk '{print $4}')
            aws s3 cp s3://$S3_BUCKET/$LATEST /tmp/restore.sql.gz
            gunzip -c /tmp/restore.sql.gz | psql -h localhost -U postgres -d shopdb
          fi
        volumeMounts:
        - name: pgdata
          mountPath: /var/lib/postgresql
      # ▼ POSTGRES CONTAINER
      containers:
        - name: postgres
          image: {{ .Values.images.postgres }}   # postgres:16-alpine
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_USER
              value: postgres
            - name: POSTGRES_PASSWORD
              value: password123
            - name: POSTGRES_DB
              value: shopdb
          volumeMounts:
            - name: pgdata
              mountPath: /var/lib/postgresql
      volumes:
        - name: pgdata
          persistentVolumeClaim:
            claimName: postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: {{ .Values.namespace }}
spec:
  ports:
    - port: 5432
      targetPort: 5432
  selector: { app: postgres }
  type: ClusterIP
```
**File:** `helm/techshop/templates/postgres-pvc.yaml` — TOÀN BỘ
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: {{ .Values.namespace }}
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: {{ .Values.postgres.storage.size }}  # 10Gi
  storageClassName: {{ .Values.postgres.storage.className }}  # gp2
```
→ Tạo: `deployment/postgres` + `service/postgres` + `pvc/postgres-pvc` (10Gi EBS) + initContainer auto-restore từ S3

### 3.4. HPA (Backend + Frontend Autoscale)
**File:** `helm/techshop/templates/hpa.yaml` — TOÀN BỘ
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: {{ .Values.namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: {{ .Values.hpa.minReplicas }}       # 2
  maxReplicas: {{ .Values.hpa.maxReplicas }}       # 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.hpa.targetCPU }}  # 50%
---
# ▼ Tương tự cho frontend-hpa
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: frontend-hpa
  namespace: {{ .Values.namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend
  minReplicas: 2
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```
→ Tạo: `hpa/backend-hpa` (min2, max5, CPU>50%) + `hpa/frontend-hpa`

### 3.5. Ingress (Web + Grafana)
**File:** `helm/techshop/templates/ingress.yaml` — TOÀN BỘ
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: techshop-ingress
  namespace: {{ .Values.namespace }}
  annotations:
    cert-manager.io/cluster-issuer: techshop-selfsigned-issuer  # ← auto TLS
spec:
  ingressClassName: nginx
  tls:
    - hosts: [{{ .Values.ingress.host | quote }}]        # techshop.local
      secretName: {{ .Values.ingress.tlsSecret }}        # techshop-tls
  rules:
    - host: {{ .Values.ingress.host }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: {{ .Values.frontend.port }}
```
**File:** `helm/techshop/templates/grafana-ingress.yaml` — TOÀN BỘ
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: {{ .Values.namespace }}
spec:
  ingressClassName: nginx
  rules:
    - host: grafana.techshop.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ .Release.Name }}-grafana     # techshop-dev-grafana
                port:
                  number: 80
```
→ Tạo: `ingress/techshop-ingress` (route web, TLS) + `ingress/grafana-ingress` (route grafana)

### 3.6. cert-manager (ClusterIssuer + Certificate)
**File:** `helm/techshop/templates/cert-manager.yaml` — TOÀN BỘ
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: techshop-selfsigned-issuer
  annotations:
    "helm.sh/hook": post-install,post-upgrade    # ← chạy sau khi Helm deploy xong
    "helm.sh/hook-weight": "5"
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: techshop-tls
  namespace: {{ .Values.namespace }}
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-weight": "10"
spec:
  secretName: {{ .Values.ingress.tlsSecret }}    # techshop-tls
  duration: 2160h       # 90 ngày
  renewBefore: 360h     # tự gia hạn trước 15 ngày
  issuerRef:
    name: techshop-selfsigned-issuer
    kind: ClusterIssuer
  dnsNames:
    - {{ .Values.ingress.host }}
```
→ Tạo: `clusterissuer/techshop-selfsigned-issuer` + `certificate/techshop-tls` → auto sinh `secret/techshop-tls`

### 3.7. ConfigMap & Secret
**File:** `helm/techshop/templates/configmap.yaml` — TOÀN BỘ
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: {{ .Values.namespace }}
data:
  FRONTEND_URL: {{ .Values.config.frontendUrl | quote }}
  JWT_EXPIRES_IN: {{ .Values.config.jwtExpiresIn | quote }}
  NODE_ENV: {{ .Values.config.nodeEnv | quote }}
  PORT: {{ .Values.backend.port | quote }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
  namespace: {{ .Values.namespace }}
data:
  BACKEND_INTERNAL_URL: {{ .Values.config.backendInternalUrl | quote }}
```
**File:** `helm/techshop/templates/secret.yaml` — TOÀN BỘ
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: backend-secrets
  namespace: {{ .Values.namespace }}
type: Opaque
stringData:
  DATABASE_URL: {{ .Values.config.databaseUrl | quote }}
  JWT_SECRET: {{ .Values.config.jwtSecret | quote }}
```
→ Tạo: `configmap/backend-config` + `configmap/frontend-config` + `secret/backend-secrets`

### 3.8. NetworkPolicy (Postgres firewall)
**File:** `helm/techshop/templates/networkpolicy.yaml` — TOÀN BỘ
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgres-allow-backend
  namespace: {{ .Values.namespace }}
spec:
  podSelector:
    matchLabels: { app: postgres }
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector:
            matchLabels: { app: backend }          # ← chỉ backend pods
        - podSelector:
            matchLabels: { app: postgres-backup }   # ← và backup pods
      ports:
        - port: 5432
          protocol: TCP
```
→ Chặn tất cả traffic đến postgres — chỉ backend + backup được phép

### 3.9. CronJob Backup (6h → dump DB → S3)
**File:** `helm/techshop/templates/postgres-backup.yaml` dòng 1-48
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: {{ .Values.namespace }}
spec:
  schedule: "{{ .Values.postgres.backup.schedule }}"   # 0 */6 * * * (mỗi 6h)
  jobTemplate:
    spec:
      template:
        metadata:
          labels: { app: postgres-backup }               # ← cho NetworkPolicy
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: postgres:16-alpine
            env:
            - name: PGHOST
              value: "postgres"                          # ← K8s service name
            - name: PGUSER
              value: postgres
            - name: PGPASSWORD
              value: password123
            - name: PGDATABASE
              value: shopdb
            - name: S3_BUCKET
              value: techshop-loki-790400775134
            - name: AWS_REGION
              value: ap-southeast-1
            command:
            - /bin/sh
            - -c
            - |
              apk add --no-cache aws-cli                  # ← cài AWS CLI
              FILE="backup-$(date +%Y%m%d-%H%M%S).sql.gz"
              pg_dump -h $PGHOST -U $PGUSER -d $PGDATABASE | gzip > /tmp/$FILE
              aws s3 cp /tmp/$FILE s3://$S3_BUCKET/$FILE   # ← upload S3
              echo "Backup: s3://$S3_BUCKET/$FILE"
```
→ Tạo: `cronjob/postgres-backup` — tự động dump `shopdb` → upload `s3://techshop-loki-790400775134/`

### 3.10. PrometheusRule (PodRestartHigh Alert)
**File:** `helm/techshop/templates/prometheus-rule.yaml` — TOÀN BỘ
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: pod-restart-alert
  namespace: {{ .Values.namespace }}
  labels:
    release: {{ .Release.Name }}          # ← KHỚP với Prometheus ruleSelector
spec:
  groups:
    - name: techshop
      rules:
        - alert: PodRestartHigh
          expr: rate(kube_pod_container_status_restarts_total{
                  namespace="{{ .Values.namespace }}"}[10m]) * 600 > 3
          for: 1m                          # ← pending 1 phút rồi mới firing
          labels:
            severity: warning
          annotations:
            summary: "Pod {{ "{{ $labels.pod }}" }} restart nhiều"
            description: "Pod restart {{ "{{ $value }}" }} lần trong 10 phút"
```
→ Tạo: `prometheusrule/pod-restart-alert` — alert khi pod restart >3 lần/10ph

### 3.11. Namespace
**File:** `helm/techshop/templates/namespace.yaml`
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: {{ .Values.namespace }}   # techshop
```
→ Tạo: `namespace/techshop`

---

## 4. HELM SUBCHARTS (Chart.yaml dependencies)

### 4.1. kube-prometheus-stack (~60 resources)
**Config:** `helm/techshop/values.yaml` → `kube-prometheus-stack:`
```yaml
kube-prometheus-stack:
  enabled: true
  prometheus:
    enabled: true
    prometheusSpec:
      ruleSelector:
        matchLabels:
          release: techshop-dev          # ← phải khớp label của PrometheusRule
  grafana:
    enabled: true
    adminPassword: admin123
  alertmanager:
    enabled: true
  defaultRules:
    enabled: true
  nodeExporter:
    enabled: true
  kubeStateMetrics:
    enabled: true
```
**Subchart:** `helm/techshop/charts/kube-prometheus-stack-*.tgz`
→ Tạo: Prometheus (StatefulSet) + Alertmanager (StatefulSet) + Grafana (Deployment) + Operator + NodeExporter (DaemonSet) + KubeStateMetrics + ~35 dashboards (ConfigMap) + ~30 PrometheusRules + ~12 ServiceMonitors

### 4.2. ingress-nginx
**Config:** `helm/techshop/values.yaml` → `ingress-nginx:`
```yaml
ingress-nginx:
  enabled: true
  controller:
    kind: DaemonSet              # ← chạy trên MỌI worker node
    service:
      type: LoadBalancer          # ← AWS NLB → public IP 52.77.232.101
    publishService:
      enabled: true
```
**Subchart:** `helm/techshop/charts/ingress-nginx-*.tgz`
→ Tạo: `daemonset/techshop-dev-ingress-nginx-controller` (3 pods trên 3 node) + `service` LoadBalancer (public IP)

### 4.3. cert-manager
**Config:** `helm/techshop/values.yaml` → `cert-manager:`
```yaml
cert-manager:
  enabled: true
  installCRDs: true
```
**Subchart:** `helm/techshop/charts/cert-manager-*.tgz`
→ Tạo: 3 Deployments (cert-manager, cainjector, webhook) + 2 Services + startup Job

### 4.4. aws-ebs-csi-driver
**Config:** `helm/techshop/values.yaml` → `aws-ebs-csi-driver:`
```yaml
aws-ebs-csi-driver:
  enabled: true
```
**Subchart:** `helm/techshop/charts/aws-ebs-csi-driver-*.tgz`
→ Tạo: `deployment/ebs-csi-controller` (2 replicas) + `daemonset/ebs-csi-node` (5 pods) — provision EBS volumes cho PVC

### 4.5. metrics-server
**Config:** `helm/techshop/values.yaml` → `metrics-server:`
```yaml
metrics-server:
  enabled: true
```
**Subchart:** `helm/techshop/charts/metrics-server-*.tgz`
→ Tạo: `deployment/techshop-dev-metrics-server` + `service` — cung cấp `kubectl top` và HPA CPU metrics

---

## 5. CI/CD — GitHub Actions

### 5.1. CI Pipeline (Build + Scan + Sign)
**File:** `.github/workflows/ci.yml`
```yaml
name: CI
on:
  push:
    branches: [main, develop]

jobs:
  lint:      # ESLint (backend) + Next.js lint (frontend)
  test:      # Jest test (backend) + tsc --noEmit (frontend)

  build-backend:
    needs: test
    if: github.ref == 'refs/heads/main'     # ← chỉ chạy khi push main
    steps:
      - docker/build-push-action@v6:        # Build image → push GHCR
          tags: ghcr.io/vinh25042005/deploy-web/backend:latest
      - aquasecurity/trivy-action:           # Scan CVE → SARIF report
      - anchore/sbom-action:                 # Generate SBOM (SPDX JSON)
      - cosign sign ...                      # Keyless sign via GitHub OIDC

  build-frontend:   # Tương tự cho frontend image
```

### 5.2. Deploy Pipeline (Verify + Rollout)
**File:** `.github/workflows/deploy-gke.yml`
```yaml
name: Deploy to K8s (AWS)
on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]
    branches: [main]

jobs:
  verify-signatures:
    steps:
      - cosign verify ghcr.io/.../backend:latest   # ← REJECT nếu ko signed
      - cosign verify ghcr.io/.../frontend:latest

  deploy-k8s:
    needs: verify-signatures
    steps:
      - name: Get kubeconfig from SSM
        run: |
          aws ssm get-parameter --region ap-southeast-1 \
            --name /k8s/kubeconfig --query Parameter.Value --output text | \
            base64 -d | gzip -d > ~/.kube/config

      - name: Deploy backend
        run: |
          kubectl set image deployment/backend backend=$REGISTRY/backend:latest -n techshop
          kubectl rollout status deployment/backend -n techshop --timeout=120s

      - name: Deploy frontend
        run: |
          kubectl set image deployment/frontend frontend=$REGISTRY/frontend:latest -n techshop
          kubectl rollout status deployment/frontend -n techshop --timeout=120s
          kubectl rollout restart deployment/frontend -n techshop
```

---

## 📁 QUICK INDEX: Resource → File + Dòng code

| Resource K8s/AWS | File | Dòng |
|---|---|---|
| `deployment/backend` | `helm/techshop/templates/backend.yaml` | 1-26 |
| `service/backend` | `helm/techshop/templates/backend.yaml` | 28-40 |
| `deployment/frontend` | `helm/techshop/templates/frontend.yaml` | 1-26 |
| `service/frontend` | `helm/techshop/templates/frontend.yaml` | 28-40 |
| `deployment/postgres` | `helm/techshop/templates/postgres.yaml` | 1-72 |
| `service/postgres` | `helm/techshop/templates/postgres.yaml` | 73-85 |
| `pvc/postgres-pvc` | `helm/techshop/templates/postgres-pvc.yaml` | 1-12 |
| `hpa/backend-hpa` | `helm/techshop/templates/hpa.yaml` | 1-18 |
| `hpa/frontend-hpa` | `helm/techshop/templates/hpa.yaml` | 19-36 |
| `ingress/techshop-ingress` | `helm/techshop/templates/ingress.yaml` | 1-20 |
| `ingress/grafana-ingress` | `helm/techshop/templates/grafana-ingress.yaml` | 1-17 |
| `clusterissuer/techshop-selfsigned-issuer` | `helm/techshop/templates/cert-manager.yaml` | 1-11 |
| `certificate/techshop-tls` | `helm/techshop/templates/cert-manager.yaml` | 12-35 |
| `configmap/backend-config` | `helm/techshop/templates/configmap.yaml` | 1-9 |
| `configmap/frontend-config` | `helm/techshop/templates/configmap.yaml` | 10-17 |
| `secret/backend-secrets` | `helm/techshop/templates/secret.yaml` | 1-8 |
| `networkpolicy/postgres-allow-backend` | `helm/techshop/templates/networkpolicy.yaml` | 1-20 |
| `cronjob/postgres-backup` | `helm/techshop/templates/postgres-backup.yaml` | 1-48 |
| `prometheusrule/pod-restart-alert` | `helm/techshop/templates/prometheus-rule.yaml` | 1-20 |
| `namespace/techshop` | `helm/techshop/templates/namespace.yaml` | 1-6 |
| 5 EC2 instances | `terraform/modules/compute/main.tf` | 71-85 |
| VPC + Subnets + IGW + NAT | `terraform/modules/network/main.tf` | 1-80 |
| S3 Bucket `techshop-loki-*` | `terraform/live/main.tf` | ~30 |
| IAM Role (S3+SSM+EBS) | `terraform/modules/compute/main.tf` | 13-65 |
| kubeadm init | `ansible/roles/master/tasks/main.yml` | 34-43 |
| Calico CNI | `ansible/roles/master/tasks/main.yml` | 54-57 |
| SSM kubeconfig upload | `ansible/roles/master/tasks/main.yml` | 72-80 |
| Prometheus+Grafana+Alertmanager (~60 resources) | `helm/techshop/Chart.yaml` subchart `kube-prometheus-stack` | — |
| ingress-nginx (DaemonSet+LB) | `helm/techshop/Chart.yaml` subchart `ingress-nginx` | — |
| cert-manager (3 Deployments+2 Svc) | `helm/techshop/Chart.yaml` subchart `cert-manager` | — |
| EBS CSI Driver | `helm/techshop/Chart.yaml` subchart `aws-ebs-csi-driver` | — |
| metrics-server | `helm/techshop/Chart.yaml` subchart `metrics-server` | — |
| CI: Build+Push+Scan+Sign | `.github/workflows/ci.yml` | toàn bộ |
| Deploy: Verify+Rollout | `.github/workflows/deploy-gke.yml` | toàn bộ |

---

> **Tổng:** 80+ resources × 25 files × hàng nghìn dòng code → map đầy đủ ở trên.
