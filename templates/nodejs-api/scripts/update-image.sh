#!/usr/bin/env bash
# ─── Update image tag trong gitops repo ─────────────────────────────
# Commit 1 dòng tag mới vào helm/<service>/env/values-<env>.yaml rồi push.
#
# Bảo mật (shift-left):
#   - Dùng SSH deploy key CHỈ push được 1 repo gitops (least privilege),
#     không dùng token PAT toàn quyền, không force-push.
#   - Git identity cố định idp-bot → audit log rõ ràng.
#
# Cách dùng:
#   ./scripts/update-image.sh <dev|stg|prd> <image-tag>
# Env bắt buộc: GITOPS_REPO, SSH_DEPLOY_KEY. Tùy chọn: GITOPS_BRANCH, SERVICE_NAME.
set -euo pipefail

ENV_NAME="${1:?usage: update-image.sh <dev|stg|prd> <image-tag>}"
IMAGE_TAG="${2:?missing image tag}"

GITOPS_REPO="${GITOPS_REPO:?set GITOPS_REPO (vd: git@github.com:owner/deploy-web.git)}"
GITOPS_BRANCH="${GITOPS_BRANCH:-main}"
SSH_DEPLOY_KEY="${SSH_DEPLOY_KEY:?set GITOPS_DEPLOY_KEY secret}"

# Service name = tên repo (bỏ hậu tố "-template" nếu có). Có thể override.
SERVICE_NAME="${SERVICE_NAME:-${GITHUB_REPOSITORY##*/}}"
SERVICE_NAME="${SERVICE_NAME%-template}"
VALUES="helm/${SERVICE_NAME}/env/values-${ENV_NAME}.yaml"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 1) Cài SSH deploy key — chỉ dùng cho repo gitops
mkdir -p "$WORK/.ssh"
printf '%s\n' "$SSH_DEPLOY_KEY" > "$WORK/.ssh/id_ed25519"
chmod 600 "$WORK/.ssh/id_ed25519"
export GIT_SSH_COMMAND="ssh -i $WORK/.ssh/id_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no"

# 2) Clone gitops (shallow, đúng branch mục tiêu)
git clone --depth 1 --branch "$GITOPS_BRANCH" "$GITOPS_REPO" "$WORK/gitops"
cd "$WORK/gitops"
git config user.name  "idp-bot"
git config user.email "idp-bot@users.noreply.github.com"

# 3) Update tag — dòng mang cờ IMAGE_TAG_ANCHOR trong values file
if ! grep -q "IMAGE_TAG_ANCHOR" "$VALUES"; then
  echo "ERROR: không tìm thấy cờ IMAGE_TAG_ANCHOR trong $VALUES" >&2
  echo "Thêm vào values file: '  tag: latest   # IMAGE_TAG_ANCHOR'" >&2
  exit 1
fi
sed -i "s|^\(  tag:\).*IMAGE_TAG_ANCHOR.*|  tag: ${IMAGE_TAG}   # IMAGE_TAG_ANCHOR|" "$VALUES"

# 4) Commit + push (pull-rebase để tránh conflict với commit khác)
git add "$VALUES"
if git diff --cached --quiet; then
  echo "Không có thay đổi — tag ${IMAGE_TAG} đã trùng ở ${ENV_NAME}."
  exit 0
fi
git pull --rebase origin "$GITOPS_BRANCH"
git commit -m "chore(${SERVICE_NAME}): bump image tag ${IMAGE_TAG} (${ENV_NAME})"
git push origin "$GITOPS_BRANCH"
echo "OK: ${VALUES} → ${IMAGE_TAG}"
