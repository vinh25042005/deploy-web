# Track A Capstone — Internal Developer Platform mini

## Đề

Xây 1 IDP mini có "golden path" cho developer:
1. Developer chọn template `nodejs-api` → trigger 1 repo mới được sinh từ template với:
   - Boilerplate code + Dockerfile + Helm chart.
   - GitHub Actions CI build + push + sign.
   - ArgoCD Application manifest tự đăng ký vào "App of apps".
2. Khi merge `main` → image tag mới → ArgoCD tự sync vào cluster dev.
3. Tag `v*.*.*` → progressive rollout sang prod (canary 10% → 50% → 100% nếu metrics ok).
4. Có dashboard Grafana view team-level: deploy frequency, lead time, error rate.

## Yêu cầu kỹ thuật

- 1 cluster k3d / kind / EKS.
- 2 repo template (`platform-templates/nodejs-api`).
- 1 repo `platform-apps` chứa App-of-apps.
- Helm chart shared trong `platform-charts/`.
- Cosign verify trong ArgoCD admission (hoặc OPA Gatekeeper).

## Deliverable

- Repo public + README + sơ đồ kiến trúc.
- Video < 7' demo từ "developer click create app" → "thấy app prod chạy".
- Trang Notion / blog mô tả lesson learned.

## Rubric (35đ)

| Hạng mục | Điểm |
|----------|------|
| Template + scaffold tự động | 6 |
| CI/CD pipeline đầy đủ + sign image | 6 |
| ArgoCD app-of-apps hoạt động | 6 |
| Progressive rollout có analysis | 6 |
| DORA-like dashboard | 4 |
| Documentation + video | 5 |
| Bonus: Backstage hoặc CLI tool | 2 |