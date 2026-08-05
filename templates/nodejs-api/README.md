# nodejs-api — Golden Path Template (IDP)

Template Node.js API theo **golden path** của IDP. Dev dùng nó để sinh repo mới
mà không cần nghĩ về CI/CD, Helm, signing, rollout.

## Cấu trúc

```
├── .github/workflows/ci.yml   # CI: test → build → push → cosign sign → update gitops
├── src/                       # Express app + /health + /metrics (prom-client)
├── test/                      # node --test (không cần framework thêm)
├── scripts/update-image.sh    # commit image tag vào gitops repo
├── Dockerfile                 # multi-stage, non-root, dumb-init
└── helm/nodejs-api/           # chart nhẹ per-service (Rollout canary + AnalysisTemplate)
```

## Tạo repo mới từ template

1. Push repo này lên GitHub và bật **Settings → General → Template repository**.
2. Dev bấm **"Use this template"** → có repo mới.
3. Đổi theo service của mình:

| Chỗ cần sửa | Chi tiết |
|---|---|
| `package.json` | `name` → tên service |
| `helm/nodejs-api/` | đổi tên thư mục + `Chart.yaml` `name` → tên service |
| `helm/nodejs-api/values.yaml` | `image.repository` → registry thật |
| `helm/nodejs-api/env/values-*.yaml` | `namespace`, `ingress.host` thật |

> ⚠️ Giữ cờ `# IMAGE_TAG_ANCHOR` trên dòng `tag:` trong `values.yaml` —
> script `update-image.sh` dựa vào cờ này để cập nhật tag.

## Secrets / Variables cần tạo trong repo GitHub

| Loại | Tên | Mô tả |
|---|---|---|
| Secret | `COSIGN_PRIVATE_KEY` | Khóa riêng cosign (sinh bằng `cosign generate-key-pair`) |
| Secret | `COSIGN_PASSWORD` | Mật khẩu khóa cosign |
| Secret | `GITOPS_REPO` | `git@github.com:<owner>/deploy-web.git` |
| Secret | `GITOPS_DEPLOY_KEY` | SSH deploy key **chỉ push được** repo gitops |
| Variable | `GITOPS_BRANCH` | Branch gitops để commit tag (mặc định `main`) |

Pub key cosign tương ứng phải nằm trong Vault → External Secrets → Secret
`cosign-pub` trong mỗi namespace service (để Kyverno `verify-image` xác minh).

## Luồng CI/CD

```
merge main → build :<sha> + sign → bump dev (gitops) → ArgoCD sync dev
tag v*     → build :<tag> + sign → bump stg + prd → Rollout canary 10→50→100
```

## Chạy cục bộ

```bash
npm ci
npm test          # node --test
npm start         # curl localhost:8080/health
```

## Validate Helm chart

```bash
helm template nodejs-api helm/nodejs-api -f helm/nodejs-api/env/values-dev.yaml
```
