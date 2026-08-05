# Báo cáo tóm tắt: Công việc đã triển khai

> Báo cáo ngắn gọn, đầy đủ về 3 phần chính: **SonarQube**, **HashiCorp Vault**, **Argo Rollouts**.

---

## 1. SonarQube — Scan code quality

**Mục tiêu:** Tự động kiểm tra chất lượng code trong CI/CD (Shift-Left Security).

**Đã triển khai:**
- Cài **SonarQube Community** (container) + **sonar-scanner** trong Jenkins.
- Thêm stage **SonarQube Scan** vào `Jenkinsfile`: quét cả `frontend/src` và `backend/src` (TypeScript) với `sonar.qualitygate.wait=true` → chất lượng code chặn luôn ở pipeline.
- Cấu hình loại trừ `node_modules`, file test; nhận diện coverage qua `lcov.info`.
- Project key `techshop-app`, token dùng `withCredentials` (không lộ trong log).

**Xử lý sự cố (đáng ghi):**
- Lỗi `CE Task FAILED` — nguyên nhân **disk host Jenkins đầy** → Elasticsearch của SonarQube tự khóa index (flood-stage watermark) → không index được dữ liệu scan.
- Fix: **dọn disk** (docker prune, image cũ) + **gỡ block `read_only_allow_delete`** trên ES indices → scan hoạt động lại, **quality gate pass**.

---

## 2. HashiCorp Vault — Quản lý secret tập trung

**Mục tiêu:** Không còn secret hardcode trong code/CI; mọi secret do Vault quản lý, tự động đồng bộ vào K8s.

**Đã triển khai:**
- **Vault standalone 1 pod** (StatefulSet `vault-0`) chạy **in-cluster**, data lưu trên **EBS volume 10Gi** (StorageClass WaitForFirstConsumer).
- **KMS auto-unseal** với AWS KMS → Vault tự unseal khi khởi động, **không cần unseal thủ công** (verified: xóa pod → tự unseal lại).
- **Secret Engine KV v2**: lưu `postgres`, `jwt`, `grafana`, `database`,...
- **Kubernetes auth method**: role `techshop` → pod/ESO xác thực bằng Service Account JWT.
- **Vault Agent Injector (thay ESO)**: app đọc secret TRỰC TIẾP từ Vault — backend/grafana dùng `agent-inject`, postgres đã dùng sẵn, backup CronJob dùng `vault` CLI + kubernetes auth. **ESO đã gỡ bỏ** (giảm 1 operator + webhook + CR, lỗi secret hiện ngay tại pod).
- **Dynamic Database Secrets**: Vault cấp credential Postgres động theo TTL (1h/24h) qua plugin `postgresql-database-plugin`.
- **Backup/recovery**: root token & unseal thông tin lưu vào **AWS SSM** (`/techshop/*`).
- **Vault Agent Injector**: tiêm secret vào pod qua annotation (dùng cho postgres lấy password từ Vault).

**Chuẩn hóa:** Mọi secret được generate ngẫu nhiên khi init, không hardcode bất kỳ đâu (chỉ reference qua SSM/Vault).

---

## 3. Argo Rollouts — Progressive Delivery

**Mục tiêu:** Triển khai an toàn với **canary** và **blue-green**, tự động kiểm tra metric (Prometheus) và **auto rollback** khi lỗi.

### 3.1. Blue-Green (Frontend)
- Rollout dùng 2 service: `frontend-active` (nhận traffic) và `frontend-preview` (bản mới).
- Deploy bản mới vào **preview** trước → kiểm tra → mới chuyển `active` (autoPromotionEnabled: false — chuyển thủ công/có kiểm soát).

### 3.2. Canary (Backend)
- Rollout canary với các bước: tăng % traffic dần theo từng giai đoạn:
  - `setWeight 20% → pause 30s → analysis → 50% → pause 30s → analysis → 80% → pause 30s → analysis → 100%`.
- Mỗi giai đoạn chạy **AnalysisRun** kiểm tra metric trước khi tăng tiếp.

### 3.3. AnalysisTemplate + Prometheus (auto rollback)
- **AnalysisTemplate `backend-error-rate`**: query Prometheus tính tỷ lệ lỗi 5xx của backend từ metric ingress-nginx (`nginx_ingress_controller_requests`, label `exported_service=backend`).
- **Success**: error-rate < 1%; **Fail**: error-rate ≥ 5% (failureLimit 3).
- Khi metric vượt ngưỡng → **AnalysisRun FAILED** → Argo Rollouts **tự động rollback** về version cũ (không cần can thiệp thủ công).
- **Traffic generator (CronJob)**: gửi ~2 request/s vào `/api` liên tục để có traffic thật cho metric đánh giá.

**Xử lý sự cố kỹ thuật (đáng ghi):**
- `result[0]` thay vì `result` (Argo Rollouts v1.9.1 trả `[]float64`).
- Label đúng là `exported_service` (không phải `service` — bị ServiceMonitor ghi đè).
- Prometheus address phải dùng **FQDN** có namespace (controller Argo ở namespace khác).
- Thêm `count` cho metric (thiếu `count` → AnalysisRun chạy vô hạn).
- Bọc `or vector(0)` để metric không bị "no data" → false failure.

---

## 4. Kết quả chung

| Hạng mục | Trạng thái |
|---|---|
| SonarQube quality gate | ✅ Pass trong CI |
| Vault (Agent Injector) + Dynamic DB secrets | ✅ Hoạt động, mọi secret đọc từ Vault, ESO đã gỡ |
| Canary analysis (Prometheus) | ✅ Metric có data thật, analysis chạy đúng |
| Blue-Green / Canary rollout | ✅ Deploy theo bước, tự động rollback khi lỗi |
