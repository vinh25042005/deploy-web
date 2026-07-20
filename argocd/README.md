# ArgoCD — GitOps cho Techshop

## Cài đặt ArgoCD

```bash
# Tạo namespace
kubectl create namespace argocd

# Cài ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Lấy password admin (mặc định là pod name)
kubectl wait --for=condition=available --timeout=5m -n argocd deployment/argocd-server
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# Port-forward để truy cập UI
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Hoặc expose qua ingress
# Truy cập: https://localhost:8080
# Username: admin
# Password: từ lệnh trên
```

## App-of-apps pattern (sẽ triển khai sau)

```
argocd/
├── README.md
├── apps/
│   ├── techshop-app.yaml        # App chính
│   ├── infra-apps.yaml          # App-of-apps cho monitoring, logging, cert-manager
│   └── kustomization.yaml
├── projects/
│   └── techshop-project.yaml    # AppProject
└── bootstrap.yaml               # App-of-apps root
```

## Sync Wave (dự kiến)

| Wave | Resources |
|------|-----------|
| -2   | CRDs (cert-manager) |
| -1   | StorageClass, Namespace |
| 0    | PostgreSQL (StatefulSet + PV) |
| 1    | Backend + Prisma migration |
| 2    | Frontend |
| 3    | Ingress + Service |
| 4    | Monitoring (Prometheus + Grafana) |

## Hooks (dự kiến)

- **PreSync**: Prisma migration job (chạy db push trước khi deploy backend mới)
- **PostSync**: Smoke test (check /api/products response 200)
- **SyncFail**: Rollback notification (Slack/webhook)

## Lưu ý

- Khi cài sau khi destroy → cluster mới → cần export KUBECONFIG
- Cert-manager CRDs bundle sẵn trong Helm chart, sync wave -2
- Ở lần deploy đầu tiên: chạy `kubectl create namespace argocd` thủ công, các namespace còn lại do ArgoCD tự tạo
