# Kế hoạch chuyển CI/CD từ GitHub Actions sang Jenkins

## Lý do
- GitHub Actions CI file `.github/workflows/ci.yml` đang chứa logic build/test/deploy ngay trong repo
- Cần tách CI/CD pipeline ra Jenkins để:
  - Quản lý tập trung trên Jenkins Server
  - Không phụ thuộc GitHub Actions credits/limits
  - Có thể trigger bằng webhook hoặc schedule
  - Lưu logs tập trung, ai cũng xem được

## Các bước thực hiện

### 1. Chuẩn bị Jenkins Server
- Jenkins có thể chạy trên EC2 riêng hoặc trong K8s cluster (Helm chart: jenkins/jenkins)
- Cần plugins:
  - Git + GitHub Integration
  - Pipeline (Declarative Pipeline)
  - Docker Pipeline
  - Kubernetes CLI
  - Trivy (hoặc dùng shell)
  - Slack Notification (optional)

### 2. Cấu hình Credentials trong Jenkins
| Credential | Loại | Dùng cho |
|-----------|------|----------|
| GitHub token | Secret text | Checkout code + push tag |
| GHCR token | Username+password | Docker push |
| Kubeconfig | Secret file | Helm deploy |
| AWS credentials | Secret text (hoặc IAM role) | Terraform + Ansible |

### 3. Pipeline Design (Jenkinsfile trong repo)

```
Jenkinsfile (Declarative Pipeline)
├── Stage: Checkout (Git)
├── Stage: Lint (npm ci + npm run lint)
│   ├── backend
│   └── frontend
├── Stage: Test (npm test + tsc --noEmit)
├── Stage: Build & Push Docker
│   ├── backend → ghcr.io/.../backend:{tag}
│   └── frontend → ghcr.io/.../frontend:{tag}
├── Stage: Security Scan (Trivy)
│   ├── Trivy scan image
│   └── Upload SARIF
├── Stage: Deploy
│   ├── terraform apply (nếu có infra change)
│   ├── ansible-playbook (nếu cần)
│   └── helm upgrade --install techshop .
└── Stage: Smoke Test
    ├── curl API check
    └── Notification (Slack/Email)
```

### 4. File cần tạo/thay đổi

| File | Action | Mô tả |
|------|--------|-------|
| `.github/workflows/ci.yml` | **Xoá** hoặc **đơn giản hoá** | Chỉ giữ lint/test, bỏ build/deploy |
| `Jenkinsfile` | **Thêm mới** | Pipeline script ở root repo |
| `jenkins/` | **Thêm mới** | Jenkins shared lib, config scripts |
| `.github/workflows/reusable-build.yml` | **Giữ nguyên** hoặc xoá | Reusable workflow nếu cần |

### 5. Trigger
- **Push trigger**: GitHub webhook → Jenkins (hoặc Poll SCM mỗi 2 phút)
- **Manual trigger**: Build with Parameters (chọn tag, branch)
- **Schedule trigger**: Jenkins cron (ví dụ nightly build)

### 6. Lưu ý khi migrate
1. Secret management: Dùng Jenkins credentials, không hardcode trong pipeline
2. Image tag strategy: Giữ nguyên `sha-{commit}` thay vì `latest`
3. Rollback: Nếu deploy fail → tự động helm rollback
4. Notification: Jenkins gửi Slack/Email kết quả build
5. Agent: Jenkins agent cần có Docker, Helm, kubectl, terraform, ansible

### 7. Jenkinsfile mẫu (sẽ tạo khi chính thức migrate)

```groovy
pipeline {
    agent any
    environment {
        REGISTRY = 'ghcr.io/vinh25042005/deploy-web'
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Lint & Test') {
            parallel {
                stage('Backend') {
                    steps {
                        dir('backend') {
                            sh 'npm ci'
                            sh 'npm run lint'
                            sh 'npm test'
                        }
                    }
                }
                stage('Frontend') {
                    steps {
                        dir('frontend') {
                            sh 'npm ci'
                            sh 'npx tsc --noEmit'
                        }
                    }
                }
            }
        }
        stage('Build & Push') {
            parallel {
                stage('Backend Image') {
                    steps {
                        sh """
                            docker build -f backend/Dockerfile \\
                                -t ${REGISTRY}/backend:sha-${GIT_COMMIT} .
                            docker push ${REGISTRY}/backend:sha-${GIT_COMMIT}
                        """
                    }
                }
                stage('Frontend Image') {
                    steps {
                        sh """
                            docker build -f frontend/Dockerfile \\
                                --build-arg BACKEND_INTERNAL_URL=http://backend:3001 \\
                                -t ${REGISTRY}/frontend:sha-${GIT_COMMIT} .
                            docker push ${REGISTRY}/frontend:sha-${GIT_COMMIT}
                        """
                    }
                }
            }
        }
        stage('Deploy') {
            steps {
                sh """
                    helm upgrade --install techshop ./helm/techshop \\
                        -n techshop --create-namespace \\
                        --set backend.image.tag=sha-${GIT_COMMIT} \\
                        --set frontend.image.tag=sha-${GIT_COMMIT}
                """
            }
        }
        stage('Smoke Test') {
            steps {
                sh 'curl -sf http://techshop.local/api/products || exit 1'
            }
        }
    }
    post {
        failure {
            // Slack notification
        }
        success {
            // Slack notification
        }
    }
}
```

## Timeline (dự kiến)

| Bước | Thời gian | Mô tả |
|------|-----------|-------|
| 1 | Day 1 | Setup Jenkins (EC2 hoặc K8s) |
| 2 | Day 1-2 | Cấu hình credentials + plugins |
| 3 | Day 2-3 | Viết Jenkinsfile |
| 4 | Day 3 | Test pipeline với 1 service |
| 5 | Day 4 | Migrate full pipeline |
| 6 | Day 5 | Cleanup GitHub Actions, monitoring pipeline |
