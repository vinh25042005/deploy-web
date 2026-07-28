# Hướng dẫn thiết lập CI/CD — Jenkins + ArgoCD Image Updater

## Kiến trúc tổng quan

```
Push code techshop-app
  → GitHub webhook → Jenkins build
  → Push Docker image (dev-<sha>, dev)
  → ArgoCD Image Updater (v1.2.2) phát hiện
  → Commit tag mới vào .argocd-source-techshop-dev.yaml
  → ArgoCD auto-sync → deploy pod mới
```

---

## 1. Jenkins (EC2 standalone)

### Cài đặt
- **File:** `terraform/jenkins-standalone/`
- Jenkins chạy Docker container `jenkins/jenkins:lts-jdk21`
- Port mapping: `9090:8080` (host:container)

### Plugins cần cài
- GitHub Integration
- Docker Pipeline
- NodeJS Plugin
- Pipeline: Stage View

### Credentials cần tạo
| ID | Loại | Dùng cho |
|---|---|---|
| `github-token` | Username with password | Clone repo techshop-app |
| `dockerhub-credentials` | Username with password | Push image lên Docker Hub |

### Jenkinsfile
- **File:** `Jenkinsfile` (root project deploy-web)
- Trigger: `githubPush()` — GitHub webhook
- Parameter: `ENV` (dev/stg/prd), `SKIP_BUILD`, `SKIP_BACKEND`, `SKIP_FRONTEND`
- Image tag format: `{ENV}-{GIT_COMMIT_SHORT}` (ví dụ: `dev-abc1234`)
- Luôn push thêm tag `{ENV}` (overwrite) — ví dụ: `dev`

### Webhook GitHub
- Repo `techshop-app` → Settings → Webhooks → `http://<JENKINS_IP>:9090/github-webhook/`
- Repo `deploy-web` → Settings → Webhooks → `http://<JENKINS_IP>:9090/github-webhook/`

---

## 2. ArgoCD (trong K8s cluster)

### Cài đặt
- **File:** `ansible/playbooks/k8s-cluster.yml` — task: `Install ArgoCD`
- Script: `kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`
- Namespace: `argocd`

### Root app (App-of-apps)
- **File:** `argocd/root.yaml`
- Source: `https://github.com/vinh25042005/deploy-web.git` (branch `capstone-week5`, path `argocd/apps`)
- Sync policy: automated, prune, selfHeal

### Child app
- **File:** `argocd/apps/techshop.yaml` (dev)
- Helm chart: `helm/techshop/` với values: `values.yaml` + `env/values-dev.yaml`
- Sync policy: automated, prune, selfHeal, CreateNamespace

---

## 3. ArgoCD Image Updater

### Cài đặt
- **File:** `ansible/playbooks/k8s-cluster.yml` — task: `Install ArgoCD Image Updater`
- Version: v1.2.2 (operator mode)
- Script: `curl -sL "https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/v1.2.2/config/install.yaml"`

### ImageUpdater CR
- **File:** `ansible/playbooks/k8s-cluster.yml` — task: `Create ImageUpdater CR`
- Nội dung:
```yaml
apiVersion: argocd-image-updater.argoproj.io/v1alpha1
kind: ImageUpdater
metadata:
  name: techshop-images
  namespace: argocd
spec:
  applicationRefs:
    - namePattern: "techshop-*"
      useAnnotations: true
```

### 3.1 Annotations trên Application

**File:** `argocd/apps/techshop.yaml`
```yaml
annotations:
  argocd-image-updater.argoproj.io/image-list: backend=docker.io/vinh2504/deploy-web-backend:dev,frontend=docker.io/vinh2504/deploy-web-frontend:dev
  argocd-image-updater.argoproj.io/write-back-method: git
  argocd-image-updater.argoproj.io/git-repository: https://github.com/vinh25042005/deploy-web.git
  argocd-image-updater.argoproj.io/git-branch: capstone-week5
  argocd-image-updater.argoproj.io/git-username: vinh25042005
  argocd-image-updater.argoproj.io/git-email: vinh2504@gmail.com
  argocd-image-updater.argoproj.io/backend.update-strategy: newest-build
  argocd-image-updater.argoproj.io/frontend.update-strategy: newest-build
  argocd-image-updater.argoproj.io/backend.helm.image-spec: images.backend
  argocd-image-updater.argoproj.io/frontend.helm.image-spec: images.frontend
```

**Giải thích annotations:**

| Annotation | Giá trị | Ý nghĩa |
|---|---|---|
| `image-list` | `backend=...:dev,frontend=...:dev` | Image cần theo dõi, filter tag `:dev` |
| `write-back-method` | `git` | Commit vào Git (không dùng `argocd` vì conflict root app) |
| `git-repository` | URL repo deploy-web | Repo để commit |
| `git-branch` | `capstone-week5` | Branch để commit |
| `update-strategy` | `newest-build` | Chọn tag có build time mới nhất |
| `helm.image-spec` | `images.backend` | Path trong Helm values cần cập nhật |

### 3.2 Credentials

#### GitHub token — ArgoCD repository credential
- **File:** `ansible/playbooks/k8s-cluster.yml` — task: `Add repository credential`
- Secret name: `repo-deploy-web` (namespace `argocd`)
- Label: `argocd.argoproj.io/secret-type: repository`
- Dùng GitHub token từ AWS SSM (`/techshop/github-token`)

#### Git credentials — Image Updater env vars
- **File:** `ansible/playbooks/k8s-cluster.yml` — task: `Patch Git credentials`
- Env vars: `ARGOCD_IMAGE_UPDATER_GIT_CREDENTIALS_USERNAME`, `ARGOCD_IMAGE_UPDATER_GIT_CREDENTIALS_PASSWORD`
- Lấy từ secret `argocd-image-updater-git-credentials`

#### Docker Hub credentials — Registry scan
- **File:** `ansible/playbooks/k8s-cluster.yml`
- Secret: `dockerhub-creds` (namespace `argocd`)
- Env vars patched: `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`
- Docker PAT từ AWS SSM (`/techshop/docker-pat`)

#### Docker Hub imagePullSecret — Node pull image
- **File:** `ansible/playbooks/k8s-cluster.yml` — task: `Create Docker Hub imagePullSecret`
- Secret: `dockerhub-secret` (namespace `techshop-dev`)
- Tham chiếu trong `helm/techshop/templates/frontend.yaml` và `backend.yaml`

### 3.3 Registry config
- Thêm vào ConfigMap `argocd-image-updater-config` (đã mount sẵn tại `/app/config/`):
```yaml
data:
  registries.conf: |
    registries:
    - name: Docker Hub
      prefix: docker.io
      api_url: https://registry-1.docker.io
      credentials: env:REGISTRY_USERNAME:REGISTRY_PASSWORD
      defaultns: library
```

---

## 4. Terraform

### File cấu hình
- `terraform/live/main.tf` — cài cluster + Ansible
- `terraform/live/variables.tf` — biến, thêm SSM data sources
- `terraform/jenkins-standalone/` — Jenkins EC2 riêng

### SSM Parameters
| Name | Mục đích | Loại |
|---|---|---|
| `/k8s/kubeconfig` | Kubeconfig cluster (gzip+base64) | String |
| `/k8s/worker-join-command` | Join command | String |
| `/techshop/github-token` | GitHub token | SecureString |
| `/techshop/docker-pat` | Docker PAT | SecureString |

### Ansible playbook
- `ansible/playbooks/k8s-cluster.yml` — cài K8s + ArgoCD + Image Updater + credentials

---

## 5. Xử lý Docker Hub rate limit

**Vấn đề:** Image Updater quét 43 tags mỗi 2 phút không auth → `429 Too Many Requests`

**Giải pháp:**
1. Xóa tags cũ trên Docker Hub (giữ 5 tags gần nhất)
2. Thêm Docker Hub credentials (env var + registries.conf)
3. Thêm imagePullSecret vào Deployment để pod pull image có auth

---

## 6. Troubleshooting

### Image Updater không hoạt động
- Kiểm tra pod: `kubectl get pods -n argocd | grep image-updater`
- Kiểm tra log: `kubectl logs -n argocd deployment/argocd-image-updater-controller --tail 30`
- Kiểm tra CR: `kubectl get imageupdater -n argocd`
- Kiểm tra annotations: `kubectl get application techshop-dev -n argocd -o yaml | grep image-updater`

### Image Updater không commit được Git
- Kiểm tra secret: `kubectl get secret repo-deploy-web -n argocd`
- Kiểm tra GitHub token còn hạn
- Kiểm tra log lỗi "could not get creds for repo"

### Docker Hub rate limit
- Kiểm tra log: `grep "toomanyrequests\|429"`
- Xóa bớt tags cũ trên Docker Hub
- Kiểm tra registry config trong ConfigMap

### ArgoCD không sync
- Kiểm tra root app: `kubectl get application techshop-root -n argocd`
- Force sync: `kubectl exec -n argocd deploy/argocd-server -- argocd app sync techshop-dev`
