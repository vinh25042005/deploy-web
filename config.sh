# Config dùng chung cho terraform + ansible
# File: config.sh

# ── AWS ──
AWS_REGION="ap-southeast-1"

# ── EC2 ──
EC2_INSTANCE_TYPE="t3.micro"
EC2_KEY_NAME="techshop-key"

# ── SSH ──
SSH_USER="ubuntu"
SSH_KEY_PATH="$HOME/.ssh/${EC2_KEY_NAME}.pem"
