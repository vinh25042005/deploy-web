# Track A — DevOps Engineer

## Đối tượng
Intern muốn làm chủ pipeline end-to-end, platform engineering, GitOps.

## Roadmap

| Tuần | Trọng tâm | Output chính |
|------|-----------|--------------|
| 5 | GitOps với ArgoCD (hoặc Flux) | App-of-apps, sync wave, hooks |
| 6 | Progressive delivery (Argo Rollouts) | Canary/blue-green với analysis template |
| 7 | Platform Engineering basics | Internal Developer Platform mini (golden path) |
| 8–9 | Capstone | Xem `capstone.md` |

## Tài liệu nên đọc

- [ArgoCD docs](https://argo-cd.readthedocs.io/)
- [Argo Rollouts](https://argoproj.github.io/argo-rollouts/)
- [Backstage docs](https://backstage.io/docs/overview/what-is-backstage)
- [Team Topologies](https://teamtopologies.com/) — chương 1 (nếu có sách).
- [Internal Developer Platform — Humanitec blog](https://humanitec.com/blog)

## Tools

- ArgoCD / Flux
- Argo Rollouts / Flagger
- Helm + Kustomize
- Crossplane (tham khảo)
- Backstage / Port (tham khảo)

## Week-by-week chi tiết

### Week 5 — GitOps với ArgoCD
- Cài ArgoCD vào cluster.
- App-of-apps pattern.
- Sync wave, hooks, prune policy.
- Lab: 3 env (dev/stg/prd), promotion qua tag image.

### Week 6 — Progressive Delivery
- Argo Rollouts: canary + blue-green.
- Analysis template kết hợp Prometheus metric.
- Auto-rollback khi error rate > 5%.

### Week 7 — Platform Engineering
- Định nghĩa "golden path": template repo + CI + ArgoCD app mặc định.
- Backstage software template (1 component minimal).
- Internal docs portal.