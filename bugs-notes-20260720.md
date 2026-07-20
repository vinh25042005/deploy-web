# Bugs & Notes — 2026-07-20

## 1. NLB Health Check sai port/path
- **Vấn đề**: NLB target group health check dùng port `3000` (var.frontend_port) và path `/`, 
  nhưng nginx ingress chỉ listen port 80 và healthz endpoint là `/healthz`.
- **Hậu quả**: Targets luôn unhealthy, NLB không forward traffic đến ingress.
- **Fix**: Sửa health check port thành `"80"` và path thành `"/healthz"`.
- **File**: `terraform/live/main.tf` lines 82-86, 98-102

## 2. Database tables chưa được tạo sau Helm deploy
- **Vấn đề**: Backend kết nối được PostgreSQL nhưng báo lỗi `table public.products does not exist`
  vì Prisma migration chưa chạy.
- **Hậu quả**: API /api/products trả về 500 Internal Server Error.
- **Fix**: Chạy `npx prisma db push` thủ công trong backend pod. 
- **Cần cải thiện**: Thêm Helm hook job chạy Prisma migration sau khi Postgres ready.

## 3. Node-2, Node-3 (private subnet) SSH qua bastion bị lỗi
- **Vấn đề**: Ansible không reachable được 2 nodes private subnet qua bastion
  (Connection closed by UNKNOWN port 65535).
- **Hậu quả**: 2/3 master nodes không join cluster — cluster chỉ có 3 nodes (1 master + 2 ingress).
- **Fix tạm**: Cluster vẫn hoạt động với 3 nodes. Cần kiểm tra SSH config và security group rules.

## 4. Terraform import NLB + NAT Gateway
- Trước khi apply lần đầu, phải import `aws_lb.ingress` và `module.network.aws_nat_gateway.main` 
  vì resources đã tồn tại ngoài state (từ lần chạy trước).
- Cần dọn 2 NAT Gateway failed state trước khi import.

## 5. Lưu ý
- EBS volumes được giữ lại nhờ `reclaimPolicy: Retain` trong StorageClass — không bị xoá khi destroy.
- NLB health check đã được fix trực tiếp trên AWS CLI (modify-target-group), 
  Terraform apply tiếp theo sẽ sync lại.
- Database đã chạy Prisma migration thủ công lần này — cần tự động hoá.
