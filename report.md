# Task Submission — GitOps với ArgoCD (Week 5)

> Phase 2 — Track DevOps

## Task: GitOps với ArgoCD

- **Intern**: Vinh Nguyen
- **Phase / Week / Day**: Phase 2 / Week 5
- **Branch**: `capstone-week5`
- **Submitted at**: 2026-07-27 15:00 (GMT+7)

---

## 1. Mục tiêu

Xây dựng GitOps CI/CD hoàn chỉnh: push code → Jenkins build → push Docker Hub → ArgoCD Image Updater tự động phát hiện image mới → commit tag vào Git → ArgoCD sync deploy pod. Áp dụng App-of-apps pattern, sync wave, hooks, và lab promotion qua tag image cho 3 môi trường (dev/stg/prd).

## 2. Kết quả

- **Cài ArgoCD + Image Updater** vào cluster qua Ansible (tích hợp trong `terraform apply`)
- **App-of-apps pattern**: Root app `argocd/root.yaml` quản lý child app `techshop-dev` trong `argocd/apps/`
- **Sync wave**: Backend (wave 1), Frontend (wave 2), Health check hook (wave 5)
- **PostSync hook**: Job `deploy-health-check` kiểm tra backend/frontend sau deploy
- **CI/CD tự động**: Push code `techshop-app` → Jenkins build → push image `dev-<sha>` + `dev` → Image Updater commit `.argocd-source-techshop-dev.yaml` → ArgoCD sync
- **3 env**: Dev (đang chạy), Stg (đã tạo file, xóa do thiếu tài nguyên)
- **Credentials**: Lưu trữ an toàn qua AWS SSM (`/techshop/github-token`, `/techshop/docker-pat`)

## 3. Khó khăn & cách giải quyết

1. **Image Updater không chạy (operator mode)** → Image Updater v1.2.2 là operator, cần `ImageUpdater` CR. Tạo CR với `applicationRefs` + `useAnnotations: true`.

2. **Root app selfHeal triệt tiêu Image Updater** → Dùng `write-back-method: argocd` thì Image Updater sửa Application spec, root app tự động revert. Đổi sang `write-back-method: git` — commit trực tiếp vào Git.

3. **Annotation write-back sai format** → `write-back-method: git:https://github.com/...` không hợp lệ. Tách thành `write-back-method: git` + `git-repository`, `git-branch`, `git-username`, `git-email`.

4. **Image Updater không push được Git** → Thiếu ArgoCD repository credential. Tạo Secret `repo-deploy-web` với label `argocd.argoproj.io/secret-type: repository`.

5. **Image Updater bị Docker Hub rate limit** → Quét 43 tags mỗi 2 phút không auth. Fix: xóa 40 tags cũ (giữ 5 tags) + thêm Docker Hub credentials (env var `REGISTRY_USERNAME`/`REGISTRY_PASSWORD`).

6. **Pod không pull được image (429 rate limit)** → Thêm `imagePullSecrets` vào Deployment + tạo `dockerhub-secret` trong namespace.

7. **Hook bị ImagePullBackOff** → `curlimages/curl` bị rate limit. Đổi sang `busybox:1.36` (đã cached).

8. **Jenkins trigger 3-4 build khi push 1 lần** → `pollSCM('* * * * *')` + `githubPush()`. Bỏ `pollSCM`, chỉ giữ `githubPush()`.

9. **Jenkins disk full** → 20+ Docker image cũ mỗi tag ~800MB. Thêm cleanup stage trong Jenkinsfile.

10. **STG quá tải tài nguyên** → Xóa `techshop-stg.yaml` khỏi `argocd/apps/` + xóa namespace.

11. **ConfigMap registry không mount được** → Tạo ConfigMap riêng `registries-config` nhưng mount sai path. Giải pháp: thêm `registries.conf` vào ConfigMap `argocd-image-updater-config` (đã mount sẵn tại `/app/config/`).

- **Time spent**: ~2 ngày
