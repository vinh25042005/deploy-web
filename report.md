# Task Submission Template

> Mỗi task = 1 thư mục con + 1 PR/MR riêng. Copy template này vào `README.md` của task.

## Task: Auto-setup Jenkins CI trên AWS EC2

- **Intern**: DevOps Intern
- **Phase / Week / Day**: Phase 2 / Week 5 / Day 1
- **Branch**: `capstone-week5`
- **Submitted at**: `2026-07-21 21:30` (timezone +07)
- **Time spent**: 6 hours

## 1. Mục tiêu

### Hạ tầng (Terraform)
- Triển khai Jenkins CI server trên AWS 

### Pipeline CI/CD
- **Lint & Test**: eslint, jest, TypeScript type-check
- **Build & Push Docker**: Build backend/frontend images → push Docker Hub
- **Security Scan**: Trivy vulnerability scan + Syft SBOM generation
- **Helm Deploy**: Deploy lên Kubernetes cluster (khi có cluster)
- **Smoke Test**: Kiểm tra ứng dụng sau deploy

## 2. Cách chạy
```bash
# 1. Clone repo
git clone https://github.com/vinh25042005/deploy-web.git
cd deploy-web

# 2. Apply Terraform (chỉ Jenkins + Network)
cd terraform/live
terraform init
terraform apply -target=module.network -auto-approve
terraform apply -target=module.jenkins -auto-approve

# 3. Đợi ~3-5 phút cho cloud-init hoàn tất
# 4. Truy cập Jenkins tại URL output
terraform output jenkins_url
# User: admin / Password: admin123
```

## 3. Kết quả
- Jenkins URL: `http://<public-ip>:9090`
- User: `admin` / Password: `admin123`
- 117 plugins đã cài sẵn (gồm docker-workflow, kubernetes-cli, blueocean, git, credentials-binding, aws-credentials)
- Security Group: mở port 9090 (Jenkins UI) + 22 (SSH)
- Instance: t3.small (2GB RAM) + 10GB gp3 disk

### Kiểm tra
```bash
# API test
curl -s -u admin:admin123 http://<jenkins-ip>:9090/api/json

# Plugins test
curl -s -u admin:admin123 http://<jenkins-ip>:9090/pluginManager/api/json?depth=1 | python3 -c "import sys,json; print(f'{len(json.load(sys.stdin)[\"plugins\"])} plugins installed')"
```

## 4. Khó khăn & cách giải quyết

### Vấn đề 1: Volume permissions
- **Mô tả**: Docker named volume tạo với user root, Jenkins (UID 1000) không ghi được
- **Fix**: Dùng bind mount `/jenkins-home:/var/jenkins_home` + `chown 1000:1000`

### Vấn đề 2: Setup Wizard
- **Mô tả**: Jenkins luôn hiện wizard khi chạy lần đầu, cần click "Install suggested plugins"
- **Fix**: Groovy init script tại `init.groovy.d/01-skip-wizard.groovy` set `InstallState.INITIALIZED` + tạo admin user

### Vấn đề 3: Plugin CLI chạy trước khi Jenkins ready
- **Mô tả**: `jenkins-plugin-cli` thất bại vì Jenkins chưa boot xong
- **Fix**: Vòng lặp `curl -s http://localhost:9090/login` chờ Jenkins ready

### Vấn đề 4: Groovy file permissions
- **Mô tả**: `sudo tee` tạo file groovy với user root
- **Fix**: `sudo chown 1000:1000 /jenkins-home/init.groovy.d/01-skip-wizard.groovy`

---

## 5. CI/CD Pipeline

### Pipeline: `techshop-ci`
- **Jenkinsfile**: `deploy-web/Jenkinsfile` trên branch `capstone-week5`
- **Trigger**: Thủ công (Build Now) hoặc Poll SCM (`H/2 * * * *`)
- **Agent**: Built-in node (Jenkins controller)

### Stages

| Stage | Mô tả | Công cụ |
|---|---|---|
| **Init** | Clone 2 repo: `techshop-app` (source) + `deploy-web` (infra/helm) | Git |
| **Lint & Test** | `npm ci` → lint (eslint) → test (jest) → type-check (tsc) | Node.js 22.x |
| **Build & Push Backend** | Docker build backend → push Docker Hub | Docker, Docker Hub |
| **Scan Backend** | Trivy vulnerability scan + Syft SBOM | Trivy, Syft |
| **Build & Push Frontend** | Docker build frontend → push Docker Hub | Docker, Docker Hub |
| **Scan Frontend** | Trivy scan + Syft SBOM | Trivy, Syft |
| **Deploy Helm** | `helm upgrade --install` lên K8s cluster | Helm, kubectl, AWS SSM |
| **Smoke Test** | Kiểm tra deploy thành công | Shell |

### Credentials
| ID | Loại | Mục đích |
|---|---|---|
| `dockerhub-credentials` | Username + Password | Docker Hub login (vinh2504) |
| `aws-access-key` | AWS Credentials | SSM get kubeconfig |
| `github-token` | Username + Password | Clone private repos |

### Các vấn đề khi chạy CI

#### Vấn đề 1: `npm: not found`
- **Nguyên nhân**: Jenkins container (`jenkins/jenkins:lts-jdk21`) không có Node.js
- **Fix**: Cài Node.js 22.x trong container: `curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y nodejs`

#### Vấn đề 2: `docker: not found`
- **Nguyên nhân**: Docker CLI không có trong Jenkins container (dù docker.sock đã mount)
- **Fix**: Cài Docker CLI trong container: `curl -fsSL https://get.docker.com | sh`

#### Vấn đề 3: Branch nhầm
- **Nguyên nhân**: Pipeline config dùng branch `*/main`, Jenkinsfile ở `capstone-week5`
- **Fix**: Sửa Branch Specifier thành `*/capstone-week5`

### Cách chạy
```bash
# Jenkins UI → techshop-ci → Build Now (tham số mặc định: ENV=dev, SKIP_BUILD=false, SKIP_DEPLOY=false)
# Hoặc dùng CLI:
curl -X POST http://<jenkins-ip>:9090/job/techshop-ci/build \
  -u admin:admin123
```

### Kết quả build (lần cuối - #4)
- Init: ✅ Clone 2 repo thành công
- Lint & Test: ✅ npm ci, lint, test, tsc pass
- Build & Push: ❌ Thiếu Docker CLI trong container (đã fix)
- Scan: ⏭ Skipped do build fail
- Deploy: ⏭ Skipped (chưa có K8s cluster)
- Smoke Test: ⏭ Skipped
