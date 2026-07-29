# SonarQube Setup cho Jenkins

Sau khi `terraform destroy && terraform apply` chạy xong, chạy script này để cài SonarQube:

## Cài tự động

```bash
ssh -o StrictHostKeyChecking=no -i ~/.ssh/techshop-key.pem ubuntu@<JENKINS_IP> bash -s << 'EOF'
# 1. Start SonarQube container
sudo docker run -d --name sonarqube --restart unless-stopped \
  -p 9000:9000 -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true sonarqube:community

# 2. Cài sonar-scanner trong Jenkins container
sudo docker exec -u root jenkins npm install -g sonar-scanner

# 3. Tạo network chung
sudo docker network create ci-network 2>/dev/null || true
sudo docker network connect ci-network sonarqube 2>/dev/null || true
sudo docker network connect ci-network jenkins 2>/dev/null || true

# 4. Đợi SonarQube UP
echo "Waiting for SonarQube..."
for i in $(seq 1 20); do
  STATUS=$(curl -s -u 'admin:admin' "http://localhost:9000/api/system/status" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)
  [ "$STATUS" = "UP" ] && echo "SonarQube ready!" && break
  sleep 10
done

# 5. Tạo project + token
curl -s -u 'admin:admin' -X POST 'http://localhost:9000/api/projects/create' \
  -d 'project=techshop-app&name=TechShop%20App'
TOKEN=$(curl -s -u 'admin:admin' -X POST 'http://localhost:9000/api/user_tokens/generate' \
  -d 'name=jenkins-ci' | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
echo "SonarQube token: $TOKEN"
EOF
```

## Cập nhật token vào Jenkinsfile

Sau khi chạy xong, lấy token từ output `SonarQube token: ...` và update vào file `Jenkinsfile`:

```bash
# Tìm dòng sonar.token trong Jenkinsfile và thay bằng token mới
sed -i "s/sonar.token=squ_[^ ]*/sonar.token=<TOKEN_MỚI>/" path/to/Jenkinsfile
git add Jenkinsfile && git commit -m "update sonar token" && git push
```

## Kiểm tra

Vào **http://localhost:9000** (user `admin` / pass `admin`) để xem SonarQube dashboard.
