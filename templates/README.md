# IDP Templates

Các **golden path template** cho developer. Mỗi template là một repo đầy đủ
(boilerplate + Dockerfile + Helm chart + GitHub Actions CI), được dùng để sinh
repo service mới.

## Cách dùng

1. Khi hoàn thiện một template: push lên repo GitHub riêng, bật **Template repository**.
2. Dev chọn template → **"Use this template"** → repo mới có sẵn CI/CD, sign,
   helm chart, và tự đăng ký vào ArgoCD (qua ApplicationSet khi có thêm folder
   `helm/<service>/` trong gitops repo).

## Danh sách

| Template | Mô tả | Trạng thái |
|---|---|---|
| `nodejs-api/` | Node.js/Express API + prom-client + Dockerfile non-root | 🚧 dev trên branch `feat/idp-nodejs-template` |
