#!/usr/bin/env bash
# =============================================================================
# vault-init.sh — user_data của Vault VM (chạy 1 lần lúc boot)
# Template Terraform: ${vault_eip} ${vault_hostname} ${vault_version}
#                    ${vault_port} ${kms_key_id} ${region}
# =============================================================================
set -euxo pipefail

# ── Cài Vault binary ──
apt-get update -qq
apt-get install -y -qq unzip openssl jq curl >/dev/null 2>&1
cd /tmp
curl -fsSL "https://releases.hashicorp.com/vault/${vault_version}/vault_${vault_version}_linux_amd64.zip" -o vault.zip
unzip -o vault.zip -d /usr/local/bin >/dev/null
vault version

# ── TLS self-signed: CA + server cert (SAN = hostname + EIP) ──
mkdir -p /etc/vault/tls /opt/vault/data
cd /etc/vault/tls
openssl genrsa -out ca.key 2048 2>/dev/null
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
  -subj "/CN=vault-ca" -out ca.crt
openssl genrsa -out server.key 2048 2>/dev/null
openssl req -new -key server.key -subj "/CN=${vault_hostname}" -out server.csr
printf "subjectAltName=DNS:${vault_hostname},IP:${vault_eip}\n" > san.cnf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days 3650 -sha256 -extfile san.cnf -out server.crt
chmod 644 ca.crt server.crt
chmod 600 ca.key server.key

# ── Cấu hình Vault (file storage + TLS + KMS auto-unseal) ──
cat > /etc/vault/config.hcl <<EOF
ui = true
disable_mlock = true
api_addr = "https://${vault_eip}:${vault_port}"

storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address       = "0.0.0.0:${vault_port}"
  tls_disable   = false
  tls_cert_file = "/etc/vault/tls/server.crt"
  tls_key_file  = "/etc/vault/tls/server.key"
}

seal "awskms" {
  region     = "${region}"
  kms_key_id = "${kms_key_id}"
}
EOF

# ── systemd service ──
cat > /etc/systemd/system/vault.service <<'UNIT'
[Unit]
Description=HashiCorp Vault
Requires=network-online.target
After=network-online.target

[Service]
User=root
Group=root
ExecStart=/usr/local/bin/vault server -config=/etc/vault/config.hcl
ExecReload=/bin/kill -HUP $${MAINPID}
KillSignal=SIGINT
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable vault
systemctl start vault

echo ">>> Vault installed on ${vault_eip}:${vault_port} (TLS, KMS seal)"
echo ">>> CA cert: /etc/vault/tls/ca.crt (copy cho clients trust)"
