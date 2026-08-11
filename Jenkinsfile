pipeline {
    agent any

    triggers {
        githubPush()
        // Auto-trigger qua Generic Webhook Trigger: webhook techshop-app POST
        // vào /generic-webhook-trigger/invoke?token=techshop-ci-trigger.
        // Lọc chỉ chạy khi push vào branch main (biến $ref từ payload).
        GenericTrigger(
            token: 'techshop-ci-trigger'
        )
    }

    parameters {
        choice(name: 'ENV', choices: ['stg', 'dev', 'prd'], description: 'Target environment')
        choice(name: 'APP_REPO_BRANCH', choices: ['main', 'techshop-app'], description: 'Build tay: chọn branch techshop-app để clone (mặc định main)')
        booleanParam(name: 'SKIP_BUILD', defaultValue: false, description: 'Skip Docker build?')
        booleanParam(name: 'SKIP_BACKEND', defaultValue: false, description: 'Skip backend (chỉ build frontend)')
        booleanParam(name: 'SKIP_FRONTEND', defaultValue: false, description: 'Skip frontend (chỉ build backend)')
        booleanParam(name: 'BUILD_FULL', defaultValue: false, description: 'Build full — bỏ qua detect thay đổi, build cả backend + frontend')
        string(name: 'DEPLOY_BRANCH', defaultValue: 'week-6-argo-rollouts', description: 'Branch deploy-web mà ArgoCD đang track (argocd/root.yaml targetRevision)')
        string(name: 'VAULT_EIP', defaultValue: '52.221.18.86', description: 'Vault VM Elastic IP — VAULT_ADDR=https://<EIP>:8200 (bắt buộc khi dùng Vault standalone)')
        booleanParam(name: 'ROTATE_DB_PASSWORD', defaultValue: false, description: 'Rotate postgres password theo secret/postgres trong Vault (ALTER DB + restart backend)')

        // ── MODE + stage gating (1 Jenkinsfile, mọi cách chạy) ──
        choice(name: 'MODE', choices: ['full', 'ci', 'release'],
               description: 'full: build+scan+sign+GitOps | ci: chỉ build+scan+sign (không commit) | release: GitOps trỏ 1 IMAGE_TAG_OVERRIDE CÓ SẴN (không build)')
        string(name: 'IMAGE_TAG_OVERRIDE', defaultValue: '', description: 'release mode: tag dùng chung cho backend + frontend (VD: stg-45) — ưu tiên thấp hơn *_BACKEND/*_FRONTEND')
        string(name: 'IMAGE_TAG_OVERRIDE_BACKEND', defaultValue: '', description: 'release mode: tag riêng cho BACKEND (nếu có sẽ thay thế IMAGE_TAG_OVERRIDE; bỏ trống = giữ nguyên)')
        string(name: 'IMAGE_TAG_OVERRIDE_FRONTEND', defaultValue: '', description: 'release mode: tag riêng cho FRONTEND (nếu có sẽ thay thế IMAGE_TAG_OVERRIDE; bỏ trống = giữ nguyên)')

        // ── [Project-generic] 1 Jenkinsfile chạy được nhiều dự án ──
        string(name: 'PROJECT_NAME', defaultValue: 'techshop', description: 'Tên dự án — namespace (<project>-<env>), ArgoCD app, .argocd-source, sonar key')
        string(name: 'APP_REPO', defaultValue: 'https://github.com/vinh25042005/techshop-app.git', description: 'Repo mã nguồn app (VD: https://github.com/org/myapp.git)')
        string(name: 'REGISTRY_BASE', defaultValue: 'docker.io/vinh2504', description: 'Docker registry base (VD: docker.io/org)')
        string(name: 'IMAGE_REPO_PREFIX', defaultValue: 'deploy-web', description: 'Tiền tố image → <prefix>-backend, <prefix>-frontend (VD: deploy-web, myapp)')
        string(name: 'VAULT_DB_PATH', defaultValue: 'secret/postgres', description: 'Vault path chứa password DB (VD: secret/myapp/postgres)')
        string(name: 'ENABLED_STAGES', defaultValue: '["fetch-secrets","cluster-secrets","sonar","build","scan","sign","verify","cleanup","gitops"]',
               description: 'JSON array bật/tắt stage. Mặc định: all. Thêm "test" (unit test) hoặc "deploy" (ArgoCD sync) khi cần.')
    }

    environment {
        REGISTRY_BASE = "${params.REGISTRY_BASE}"
        // Tên image đầy đủ — <REGISTRY_BASE>/<IMAGE_REPO_PREFIX>-backend / -frontend
        IMAGE_BACKEND  = "${params.REGISTRY_BASE}/${params.IMAGE_REPO_PREFIX}-backend"
        IMAGE_FRONTEND = "${params.REGISTRY_BASE}/${params.IMAGE_REPO_PREFIX}-frontend"
        GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()

        // Vault — CI đọc secret TRỰC TIẾP từ Vault VM qua HashiCorp Vault Plugin
        //   (hashicorp-vault-plugin + hashicorp-vault-pipeline, credential AppRole:
        //    vault-approle-jenkins. URL/engine/skipSSL đã cấu hình ở Jenkins global config.)
        //   Plugin tự login AppRole + renew; secret được mask, không in ra log.
        VAULT_ADDR = "https://${params.VAULT_EIP}:8200"
        GITHUB_TOKEN  = vault path: 'secret/ci/github', key: 'token'
        GITHUB_USER   = vault path: 'secret/ci/github', key: 'username'
        DOCKER_USER   = vault path: 'secret/ci/dockerhub', key: 'username'
        DOCKER_PAT    = vault path: 'secret/ci/dockerhub', key: 'token'
        SONAR_TOKEN   = vault path: 'secret/ci/sonar', key: 'token'
        COSIGN_PRIVATE_KEY = vault path: 'secret/ci/cosign', key: 'private_key'
        COSIGN_PUBLIC_KEY  = vault path: 'secret/cosign', key: 'public_key'
        // Password postgres — 1 nguồn chân lý duy nhất (postgres init + backend DATABASE_URL)
        DB_PASSWORD = vault path: params.VAULT_DB_PATH, key: 'password'

        // ACTIVE_ENV / IMAGE_TAG / APP_BRANCH được tính trong stage "Resolve ENV"
        APP_REPO = "${params.APP_REPO}"
    }

    stages {
        // ── Initialization — đặt danh tính build sớm ──
        stage('Initialization') {
            steps {
                script {
                    currentBuild.displayName = "${params.PROJECT_NAME} · #${BUILD_NUMBER}"
                    def src = env.GITHUB_BRANCH ? "Webhook: ${env.GITHUB_BRANCH}" : 'Manual'
                    echo ">>> Pipeline ${params.PROJECT_NAME} khởi động — trigger: ${src}"
                }
            }
        }

        // ── Resolve ENV theo branch (auto-trigger) hoặc param (manual) ──────
        //   Auto (webhook push): main/release/staging → stg, branch khác → dev
        //   Manual (Build with Parameters): dùng ENV đã chọn
        stage('Resolve ENV') {
            steps {
                script {
                    if (env.GITHUB_BRANCH) {
                        def branch = env.GITHUB_BRANCH
                        echo "Auto-trigger từ branch: ${branch}"
                        env.ACTIVE_ENV = (branch == 'main' || branch == 'release' || branch == 'staging') ? 'stg' : 'dev'
                        env.APP_BRANCH = branch
                    } else {
                        env.ACTIVE_ENV = params.ENV
                        env.APP_BRANCH = params.APP_REPO_BRANCH
                        echo "Manual build: ENV=${env.ACTIVE_ENV}, branch=${env.APP_BRANCH}"
                    }
                    env.IMAGE_TAG = "${env.ACTIVE_ENV}-${BUILD_NUMBER}"

                    // ── [All-in-one] MODE + ENABLED_STAGES ──
                    env.MODE = params.MODE
                    enabledStages = parseEnabledStages(params.ENABLED_STAGES)
                    currentBuild.displayName = "${params.PROJECT_NAME} · ${env.ACTIVE_ENV} · ${params.MODE} · #${BUILD_NUMBER}"
                    echo "→ MODE=${env.MODE} | ENABLED_STAGES=${enabledStages}"

                    if (params.MODE == 'release') {
                        // Deploy lại 1 tag CÓ SẴN — không build/scan, chỉ GitOps trỏ tới tag đó
                        def tag = params.IMAGE_TAG_OVERRIDE ?: env.IMAGE_TAG
                        env.IMAGE_TAG = tag
                        env.BUILD_BACKEND = 'true'
                        env.BUILD_FRONTEND = 'true'
                        echo "release mode → GitOps sẽ trỏ ${env.ACTIVE_ENV} (backend=${params.IMAGE_TAG_OVERRIDE_BACKEND ?: (params.IMAGE_TAG_OVERRIDE ?: 'giữ nguyên')} | frontend=${params.IMAGE_TAG_OVERRIDE_FRONTEND ?: (params.IMAGE_TAG_OVERRIDE ?: 'giữ nguyên')})"
                    } else if (params.MODE == 'ci') {
                        echo "ci mode → build+scan+sign, KHÔNG commit GitOps"
                    }
                    echo "→ ACTIVE_ENV=${env.ACTIVE_ENV} | IMAGE_TAG=${env.IMAGE_TAG}"
                }
            }
        }

        // ── Select Execution Mode — gate thủ công cho PRD ──
        //   Chỉ kích hoạt khi build tay ENV=prd (webhook không bao giờ đụng prd).
        stage('Select Execution Mode') {
            when { expression { params.ENV == 'prd' && !env.GITHUB_BRANCH } }
            steps {
                script {
                    def confirm = input(
                        id: 'prdConfirm',
                        message: "⚠️ DEPLOY PRODUCTION: ${env.ACTIVE_ENV} @ ${env.IMAGE_TAG} — xác nhận?",
                        parameters: [booleanParameter(name: 'CONFIRM', defaultValue: false, description: 'Tick để xác nhận deploy production')]
                    )
                    if (!confirm) { error 'Không xác nhận → hủy deploy prd' }
                    echo '>>> Đã xác nhận deploy production'
                }
            }
        }

        // ── Get Release Info — in thông tin release ──
        stage('Get Release Info') {
            steps {
                script {
                    echo '────────────────────── Release info ──────────────────────'
                    echo "Project     : ${params.PROJECT_NAME}"
                    echo "Environment : ${env.ACTIVE_ENV}"
                    echo "Mode        : ${params.MODE}"
                    echo "Stages      : ${enabledStages}"
                    echo "Image Tag   : ${env.IMAGE_TAG}"
                    echo "App Branch  : ${env.APP_BRANCH}"
                    echo "Deploy Repo : ${params.DEPLOY_BRANCH}"
                    echo '──────────────────────────────────────────────────────────'
                }
            }
        }

        // ── Secret đã được nạp TỰ ĐỘNG qua HashiCorp Vault Plugin (environment) ──
        //   Jenkins đọc TRỰC TIẾP từ Vault (không qua ESO/k8s) bằng AppRole credential
        //   `vault-approle-jenkins` (Vault role: jenkins, policy: techshop-ci).
        //   Stage này chỉ: kiểm tra secret đã load + cấu hình git credential helper.
        stage('Fetch Secrets from Vault') {
            when { expression { stageEnabled('fetch-secrets') } }
            steps {
                script {
                    // 0) Fail sớm nếu Vault/AppRole lỗi → secret rỗng
                    //    LƯU Ý sandbox: env[var] (getAt động) bị script-security chặn
                    //    → resolve bằng env.VAR tĩnh trước, rồi mới vòng lặp kiểm tra.
                    def secrets = [
                        'GITHUB_TOKEN': env.GITHUB_TOKEN,
                        'GITHUB_USER': env.GITHUB_USER,
                        'DOCKER_USER': env.DOCKER_USER,
                        'DOCKER_PAT': env.DOCKER_PAT,
                        'SONAR_TOKEN': env.SONAR_TOKEN,
                        'COSIGN_PRIVATE_KEY': env.COSIGN_PRIVATE_KEY,
                        'COSIGN_PUBLIC_KEY': env.COSIGN_PUBLIC_KEY,
                        'DB_PASSWORD': env.DB_PASSWORD
                    ]
                    secrets.each { k, v ->
                        if (!v || v.trim().isEmpty()) {
                            error "Thiếu secret '${k}' từ Vault — kiểm tra AppRole credential & Vault reachable."
                        }
                    }
                    echo '>>> Đã nạp secret từ Vault (HashiCorp Vault Plugin / AppRole) — không in giá trị'

                    // Git credential helper — dùng cho clone app + push deploy repo
                    //    (tránh nhúng token vào URL/log)
                    sh """
                        printf 'https://x-access-token:%s@github.com\\n' "\$GITHUB_TOKEN" > ~/.git-credentials
                        chmod 600 ~/.git-credentials
                        git config --global credential.helper store
                    """
                }
            }
        }
        // ── Fetch Kubeconfig (SSM) — cluster destroy/apply nhiều lần, IP đổi ──
        //   Mỗi lần chạy pipeline: lấy kubeconfig MỚI NHẤT từ SSM (base64+gzip) →
        //   ghi ~/.kube/config → kubectl luôn trỏ đúng API server hiện tại.
        //   Ưu tiên path PER-PROJECT: /k8s/<PROJECT>-<ENV>/kubeconfig (terraform
        //   mới ghi per-project). Fallback global /k8s/kubeconfig (cluster cũ).
        //   Agent dùng IAM instance role (techshop-jenkins-role), không hardcode key.
        stage('Fetch Kubeconfig (SSM)') {
            steps {
                script {
                    env.SSM_KUBECONFIG_PATH = sh(
                        script: '''
                            set -e
                            PER_PROJECT="/k8s/${PROJECT_NAME}-${ENV}/kubeconfig"
                            GLOBAL="/k8s/kubeconfig"
                            if aws ssm get-parameter --name "$PER_PROJECT" --with-decryption --query Parameter.Value --output text >/dev/null 2>&1; then
                                echo "$PER_PROJECT"
                            else
                                echo "$GLOBAL"
                            fi
                        ''',
                        returnStdout: true
                    ).trim()
                }
                sh """
                    set -e
                    echo ">>> SSM kubeconfig: ${env.SSM_KUBECONFIG_PATH}"
                    aws ssm get-parameter --name "${env.SSM_KUBECONFIG_PATH}" --with-decryption \\
                      --query 'Parameter.Value' --output text | base64 -d | gunzip > ~/.kube/config
                    chmod 600 ~/.kube/config
                    kubectl get ns >/dev/null 2>&1 && echo '>>> Kubeconfig OK (từ SSM)' || { echo 'ERROR: kubectl không kết nối được cluster — kiểm tra SSM kubeconfig'; exit 1; }
                """
            }
        }
        // ── Rotate postgres password (theo secret/postgres trong Vault) ──────
        //   Cách dùng: 1) đổi password trong Vault (vault kv patch secret/postgres password=<mới>)
        //              2) chạy build này với ROTATE_DB_PASSWORD=true
        //   → CI đọc pass MỚI từ Vault → ALTER user postgres trong DB
        //     → restart backend (pod mới source secret mới, DATABASE_URL tự ghép từ secret/postgres)
        //   LƯU Ý: password KHÔNG được chứa ký tự ' (sẽ phá vỡ lệnh ALTER).
        stage('Rotate DB Password') {
            when { expression { params.ROTATE_DB_PASSWORD } }
            steps {
                script {
                    // 1) Đổi password THẬT trong postgres (exec qua socket local — không cần pass cũ)
                    sh """
                        set -e
                        echo "ALTER USER postgres WITH PASSWORD '${DB_PASSWORD}';" | \\
                          kubectl exec -i -n ${params.PROJECT_NAME}-${env.ACTIVE_ENV} pod/postgres-0 -- psql -U postgres -d shopdb
                        echo '>>> Đã ALTER password postgres trong DB'
                    """
                    // 2) Restart backend — pod mới source secret mới từ Vault (DATABASE_URL tự ghép)
                    script {
                        def restartAt = new Date().format("yyyy-MM-dd'T'HH:mm:ss'Z'", TimeZone.getTimeZone('UTC'))
                        sh "kubectl -n ${params.PROJECT_NAME}-${env.ACTIVE_ENV} patch rollout backend --type merge -p '{\"spec\":{\"restartAt\":\"${restartAt}\"}}'"
                    }
                    // 3) Chờ + verify backend không CrashLoop
                    sh """
                        sleep 25
                        kubectl get pods -n ${params.PROJECT_NAME}-${env.ACTIVE_ENV} -l app=backend
                    """
                }
            }
        }
        // ── Reconcile k8s Secret phái sinh TỪ Vault (thay ESO, không qua ESO) ──
        //   - dockerhub-secret (imagePullSecret) ← secret/ci/dockerhub
        //   - cosign-pub (Kyverno verify image) ← secret/cosign (public key)
        //   Lỗi hiện ngay tại stage này, không bị giấu trong trạng thái sync operator.
        stage('Reconcile Cluster Secrets (từ Vault)') {
            when { expression { stageEnabled('cluster-secrets') } }
            steps {
                script {
                    sh """
                        set -e
                        for ns in ${params.PROJECT_NAME}-dev ${params.PROJECT_NAME}-stg; do
                            if kubectl get namespace "\$ns" >/dev/null 2>&1; then
                                kubectl create secret docker-registry dockerhub-secret -n "\$ns" \\
                                    --docker-server=docker.io \\
                                    --docker-username="\$DOCKER_USER" \\
                                    --docker-password="\$DOCKER_PAT" \\
                                    --dry-run=client -o yaml | kubectl apply -f -
                                echo "  ✅ dockerhub-secret đã sync (\$ns) từ Vault"
                            else
                                echo "  ⏭️  bỏ qua \$ns (namespace chưa tồn tại)"
                            fi
                        done
                    """
                    sh """
                        set -e
                        printf '%s' "\$COSIGN_PUBLIC_KEY" > /tmp/cosign.pub
                        if kubectl get namespace ${params.PROJECT_NAME}-stg >/dev/null 2>&1; then
                            kubectl create secret generic cosign-pub -n ${params.PROJECT_NAME}-stg \\
                                --from-file=cosign.pub=/tmp/cosign.pub \\
                                --dry-run=client -o yaml | kubectl apply -f -
                            echo '  ✅ cosign-pub đã sync (${params.PROJECT_NAME}-stg) từ Vault'
                        fi
                    """
                }
            }
        }

        stage('Init') {
            parallel {
                stage('Clone App Source') {
                    steps {
                        script {
                            if (params.MODE == 'release') {
                                echo 'release mode → bỏ qua clone app source (dùng IMAGE_TAG_OVERRIDE)'
                            } else {
                                dir('app-source') {
                                    // Token GitHub nạp từ Vault (secret/ci/github) qua git credential helper
                                    sh "git clone --branch '${APP_BRANCH}' '${APP_REPO}' ."
                                    script {
                                        // Commit thật của app-source — dùng cho SLSA provenance materials
                                        env.APP_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                                        env.APP_COMMIT_FULL  = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
                                        echo "→ App source commit: ${env.APP_COMMIT_SHORT}"
                                    }
                                }
                            }
                        }
                    }
                }
                stage('Clone Deploy Repo') {
                    steps {
                        dir('deploy-web') {
                            checkout scm
                        }
                    }
                }
            }
        }

        stage('Check changes') {
            when { expression { params.MODE != 'release' } }
            steps {
                dir('app-source') {
                    script {
                        def changed = sh(
                            script: 'git diff --name-only HEAD~1 2>/dev/null || echo "first-build"',
                            returnStdout: true
                        ).trim()
                        if (params.BUILD_FULL) {
                            env.BUILD_BACKEND = 'true'
                            env.BUILD_FRONTEND = 'true'
                            echo "BUILD_FULL=true → build cả backend + frontend (bỏ qua detect thay đổi)"
                        } else if (changed == 'first-build') {
                            env.BUILD_BACKEND = 'true'
                            env.BUILD_FRONTEND = 'true'
                            echo "First build → build all"
                        } else {
                            env.BUILD_BACKEND = changed.contains('backend/') ? 'true' : 'false'
                            env.BUILD_FRONTEND = changed.contains('frontend/') ? 'true' : 'false'
                            echo "Changed files: ${changed.split('\n').join(', ')}"
                        }
                        echo "→ Build backend: ${env.BUILD_BACKEND}"
                        echo "→ Build frontend: ${env.BUILD_FRONTEND}"
                    }
                }
            }
        }

        // ── [TẠM TẮT] Lint & Test matrix (Node 18/20/22) — đang comment để bỏ qua, bật lại bằng cách bỏ // ──
        // stage('Lint & Test') {
        //     when { expression { !params.SKIP_BUILD && (env.BUILD_BACKEND != 'false' || env.BUILD_FRONTEND != 'false') } }
        //     matrix {
        //         axes {
        //             axis {
        //                 name 'NODE_VERSION'
        //                 values '18', '20', '22'
        //             }
        //         }
        //         stages {
        //             stage('Backend (Node $NODE_VERSION)') {
        //                 steps {
        //                     sh """
        //                         rm -rf app-source-backend-${NODE_VERSION}
        //                         cp -r app-source/backend app-source-backend-${NODE_VERSION}
        //                     """
        //                     dir("app-source-backend-${NODE_VERSION}") {
        //                         sh """#!/bin/bash
        //                             if [ "${NODE_VERSION}" != "22" ]; then
        //                                 export NVM_DIR=/var/jenkins_home/.nvm
        //                                 [ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
        //                                 nvm use ${NODE_VERSION}
        //                             fi
        //                             npm ci
        //                             npm run lint 2>/dev/null || true
        //                             npm test 2>/dev/null || true
        //                         """
        //                     }
        //                 }
        //             }
        //             stage('Frontend (Node $NODE_VERSION)') {
        //                 steps {
        //                     sh """
        //                         rm -rf app-source-frontend-${NODE_VERSION}
        //                         cp -r app-source/frontend app-source-frontend-${NODE_VERSION}
        //                     """
        //                     dir("app-source-frontend-${NODE_VERSION}") {
        //                         sh """#!/bin/bash
        //                             if [ "${NODE_VERSION}" != "22" ]; then
        //                                 export NVM_DIR=/var/jenkins_home/.nvm
        //                                 [ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
        //                                 nvm use ${NODE_VERSION}
        //                             fi
        //                             npm ci
        //                             npx tsc --noEmit 2>/dev/null || true
        //                         """
        //                     }
        //                 }
        //             }
        //         }
        //     }
        // }

        // ── Unit Test — chạy test trước deploy ──
        //   MẶC ĐỊNH TẮT — bật bằng cách thêm "test" vào ENABLED_STAGES.
        //   Yêu cầu agent đã có node/npm.
        stage('Unit Test') {
            when { expression { params.MODE != 'release' && !params.SKIP_BUILD && stageEnabled('test') } }
            steps {
                dir('app-source') {
                    script {
                        if (env.BUILD_BACKEND != 'false' && fileExists('backend/package.json')) {
                            dir('backend') { sh 'npm ci --no-audit --no-fund 2>&1 && npm test 2>&1' }
                        }
                        if (env.BUILD_FRONTEND != 'false' && fileExists('frontend/package.json')) {
                            dir('frontend') { sh 'npm ci --no-audit --no-fund 2>&1 && npx tsc --noEmit 2>&1' }
                        }
                    }
                }
            }
        }

        stage('SonarQube Scan') {
            when { expression { params.MODE != 'release' && !params.SKIP_BUILD && stageEnabled('sonar') && (env.BUILD_BACKEND != 'false' || env.BUILD_FRONTEND != 'false') } }
            steps {
                dir('app-source') {
                    sh """
                        set -e
                        sonar-scanner \\
                            -Dsonar.projectKey=${params.PROJECT_NAME}-app \\
                            -Dsonar.sources=frontend/src,backend/src \\
                            -Dsonar.host.url=http://sonarqube:9000 \\
                            -Dsonar.token=\$SONAR_TOKEN \\
                            -Dsonar.qualitygate.wait=true \\
                            -Dsonar.exclusions=**/node_modules/**,**/*.test.ts,**/*.spec.ts \\
                            -Dsonar.javascript.lcov.reportPaths=backend/coverage/lcov.info,frontend/coverage/lcov.info 2>&1
                    """
                }
            }
        }

        stage('Build & Push Backend') {
            when { expression { params.MODE != 'release' && !params.SKIP_BUILD && !params.SKIP_BACKEND && stageEnabled('build') && env.BUILD_BACKEND != 'false' } }
            steps {
                dir('app-source') {
                    sh """
                        set -e
                        echo \$DOCKER_PAT | docker login -u \$DOCKER_USER --password-stdin
                        docker build -f backend/Dockerfile \\
                            -t ${IMAGE_BACKEND}:${IMAGE_TAG} \
                            -t ${IMAGE_BACKEND}:${ACTIVE_ENV} \
                            .
                        docker push ${IMAGE_BACKEND}:${IMAGE_TAG}
                        docker push ${IMAGE_BACKEND}:${ACTIVE_ENV}
                    """
                }
            }
        }

        stage('Scan Backend') {
            when { expression { params.MODE != 'release' && !params.SKIP_BUILD && !params.SKIP_BACKEND && stageEnabled('scan') && env.BUILD_BACKEND != 'false' } }
            steps {
                dir('app-source') {
                    sh """
                        trivy image ${IMAGE_BACKEND}:${IMAGE_TAG} \
                            --severity CRITICAL,HIGH \
                            --scanners vuln \
                            --format table \
                            --exit-code 0 2>&1 | \
                            grep -v "node_modules" | \
                            tee trivy-backend.txt || true

                        trivy image ${IMAGE_BACKEND}:${IMAGE_TAG} \
                            --severity CRITICAL,HIGH \
                            --format sarif \
                            --output trivy-backend.sarif \
                            --exit-code 0 || true

                        syft ${IMAGE_BACKEND}:${IMAGE_TAG} \
                            -o spdx-json=sbom-backend.spdx.json || true
                    """
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'app-source/trivy-backend.txt, app-source/trivy-backend.sarif, app-source/sbom-backend.spdx.json', allowEmptyArchive: true
                }
            }
        }

        stage('Build & Push Frontend') {
            when { expression { params.MODE != 'release' && !params.SKIP_BUILD && !params.SKIP_FRONTEND && stageEnabled('build') && env.BUILD_FRONTEND != 'false' } }
            steps {
                dir('app-source') {
                    sh """
                        set -e
                        echo \$DOCKER_PAT | docker login -u \$DOCKER_USER --password-stdin
                        docker build -f frontend/Dockerfile \\
                            --build-arg BACKEND_INTERNAL_URL=http://backend:3001 \\
                            -t ${IMAGE_FRONTEND}:${IMAGE_TAG} \
                            -t ${IMAGE_FRONTEND}:${ACTIVE_ENV} \
                            .
                        docker push ${IMAGE_FRONTEND}:${IMAGE_TAG}
                        docker push ${IMAGE_FRONTEND}:${ACTIVE_ENV}
                    """
                }
            }
        }

        stage('Scan Frontend') {
            when { expression { params.MODE != 'release' && !params.SKIP_BUILD && !params.SKIP_FRONTEND && stageEnabled('scan') && env.BUILD_FRONTEND != 'false' } }
            steps {
                dir('app-source') {
                    sh """
                        trivy image ${IMAGE_FRONTEND}:${IMAGE_TAG} \
                            --severity CRITICAL,HIGH \
                            --scanners vuln \
                            --format table \
                            --exit-code 0 2>&1 | \
                            grep -v "node_modules" | \
                            tee trivy-frontend.txt || true

                        trivy image ${IMAGE_FRONTEND}:${IMAGE_TAG} \
                            --severity CRITICAL,HIGH \
                            --format sarif \
                            --output trivy-frontend.sarif \
                            --exit-code 0 || true

                        syft ${IMAGE_FRONTEND}:${IMAGE_TAG} \
                            -o spdx-json=sbom-frontend.spdx.json || true
                    """
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'app-source/trivy-frontend.txt, app-source/trivy-frontend.sarif, app-source/sbom-frontend.spdx.json', allowEmptyArchive: true
                }
            }
        }

        // ── Ký image + SBOM + SLSA provenance (supply-chain security) ──────────
        //   Private key lấy TRỰC TIẾP từ Vault (secret/ci/cosign) + env COSIGN_PASSWORD.
        //   Key được ghi ra file (printf giữ nguyên newline — env:// làm vỡ PEM block).
        //   Public key export ra cosign-public.pem → dùng cho Kyverno/OPA verify khi deploy.
        stage('Sign & Attest (Cosign + SLSA)') {
            when { expression { params.MODE != 'release' && !params.SKIP_BUILD && stageEnabled('sign') && (env.BUILD_BACKEND != 'false' || env.BUILD_FRONTEND != 'false') } }
            steps {
                dir('app-source') {
                    // Sinh SLSA provenance JSON bằng Groovy (tránh escape $ trong shell heredoc)
                    script {
                        def prov = [
                            builder: [id: "https://jenkins/${params.PROJECT_NAME}-ci"],
                            buildType: "https://jenkins/${params.PROJECT_NAME}-ci",
                            invocation: [
                                configSource: [uri: 'git+https://github.com/vinh25042005/deploy-web.git', digest: [sha1: env.GIT_COMMIT_SHORT]]
                            ],
                            metadata: [buildStartedOn: new Date().format("yyyy-MM-dd'T'HH:mm:ss'Z'", TimeZone.getTimeZone('UTC'))],
                            materials: [
                                [uri: params.APP_REPO, digest: [sha1: env.APP_COMMIT_FULL]]
                            ]
                        ]
                        writeFile file: 'slsa-provenance.json', text: groovy.json.JsonOutput.toJson(prov)
                    }
                    // ── Chuẩn hóa PEM bằng Groovy (tránh shell heredoc bị indent → syntax error) ──
                    //   Key lấy TRỰC TIẾP từ Vault (secret/ci/cosign) — không qua Jenkins Credential.
                    //   Jenkins Secret text có thể dồn key thành 1 dòng hoặc giữ '\n' literal
                    //   → cosign báo "invalid pem block". Groovy tự rebuild PEM đúng chuẩn.
                    script {
                        // KHÔNG lưu Matcher vào biến (Matcher không serializable → NotSerializableException
                        // khi Jenkins lưu trạng thái pipeline). Dùng inline [0][1] để lấy String ngay.
                        def rawKey = env.COSIGN_PRIVATE_KEY.replace('\\n', '\n')  // literal \n → newline
                            def header = "-----BEGIN ${(rawKey =~ /-----BEGIN ([^-]+)-----/)[0][1]}-----"
                            def footer = "-----END ${(rawKey =~ /-----END ([^-]+)-----/)[0][1]}-----"
                            def body = rawKey
                                .replaceAll(/-----BEGIN [^-]+-----/, '')
                                .replaceAll(/-----END [^-]+-----/, '')
                                .replaceAll(/\s+/, '')                             // strip whitespace
                            def wrapped = body.replaceAll(/(.{64})/, '$1\n')       // wrap 64 ký tự/dòng
                            writeFile file: 'cosign.key', text: "${header}\n${wrapped}\n${footer}\n"
                            sh 'chmod 600 cosign.key'
                        }
                        sh """#!/bin/bash
                            set -e
                            export COSIGN_PASSWORD="\${COSIGN_PASSWORD:-}"

                            echo ">>> Kiểm tra key format:"
                            head -1 cosign.key
                            wc -l cosign.key

                            cosign version 2>&1 | head -1

                            
                            echo ">>> SLSA provenance:"
                            cat slsa-provenance.json

                            if [ "${env.BUILD_BACKEND}" != "false" ]; then
                              echo ">>> Sign backend..."
                              cosign attach sbom --sbom sbom-backend.spdx.json \
                                ${IMAGE_BACKEND}:${IMAGE_TAG} || true
                              cosign sign --yes --key cosign.key \
                                ${IMAGE_BACKEND}:${IMAGE_TAG}
                              cosign attest --yes --key cosign.key \
                                --type https://slsa.dev/provenance/v1 \
                                --predicate slsa-provenance.json \
                                ${IMAGE_BACKEND}:${IMAGE_TAG}
                            fi

                            if [ "${env.BUILD_FRONTEND}" != "false" ]; then
                              echo ">>> Sign frontend..."
                              cosign attach sbom --sbom sbom-frontend.spdx.json \
                                ${IMAGE_FRONTEND}:${IMAGE_TAG} || true
                              cosign sign --yes --key cosign.key \
                                ${IMAGE_FRONTEND}:${IMAGE_TAG}
                              cosign attest --yes --key cosign.key \
                                --type https://slsa.dev/provenance/v1 \
                                --predicate slsa-provenance.json \
                                ${IMAGE_FRONTEND}:${IMAGE_TAG}
                            fi

                            # Dọn key private khỏi workspace sau khi dùng
                            rm -f cosign.key

                            echo ">>> Sign & Attest hoàn tất"
                        """
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'app-source/cosign-public.pem', allowEmptyArchive: true
                }
            }
        }

        // ── Verify Image (cosign) — pre-deploy gate (shift-left) ──
        //   Xác nhận image vừa ký khớp public key CHÍNH mà Kyverno sẽ dùng
        //   (cosign-pub ← secret/cosign). Lệch key → fail SỚM ở CI, không đợi
        //   Kyverno chặn lúc deploy. KHÔNG chạy pod — chỉ đọc registry.
        stage('Verify Image (cosign)') {
            when { expression { params.MODE != 'release' && !params.SKIP_BUILD && stageEnabled('verify') && (env.BUILD_BACKEND != 'false' || env.BUILD_FRONTEND != 'false') } }
            steps {
                dir('app-source') {
                    // Chuẩn hóa public key PEM từ Vault (tránh lỗi "invalid pem block")
                    script {
                        def raw = env.COSIGN_PUBLIC_KEY.replace('\\n', '\n')
                        def header = "-----BEGIN ${(raw =~ /-----BEGIN ([^-]+)-----/)[0][1]}-----"
                        def footer = "-----END ${(raw =~ /-----END ([^-]+)-----/)[0][1]}-----"
                        def body = raw
                            .replaceAll(/-----BEGIN [^-]+-----/, '')
                            .replaceAll(/-----END [^-]+-----/, '')
                            .replaceAll(/\s+/, '')
                        def wrapped = body.replaceAll(/(.{64})/, '$1\n')
                        writeFile file: 'cosign.pub', text: "${header}\n${wrapped}\n${footer}\n"
                    }
                    sh """#!/bin/bash
                        set -e
                        if [ "${env.BUILD_BACKEND}" != "false" ]; then
                          echo ">>> Verify backend: ${IMAGE_BACKEND}:${IMAGE_TAG}"
                          cosign verify --key cosign.pub ${IMAGE_BACKEND}:${IMAGE_TAG}
                          echo "  ✅ backend chữ ký hợp lệ"
                        fi
                        if [ "${env.BUILD_FRONTEND}" != "false" ]; then
                          echo ">>> Verify frontend: ${IMAGE_FRONTEND}:${IMAGE_TAG}"
                          cosign verify --key cosign.pub ${IMAGE_FRONTEND}:${IMAGE_TAG}
                          echo "  ✅ frontend chữ ký hợp lệ"
                        fi
                        rm -f cosign.pub
                    """
                }
            }
        }

        // ── Cleanup — dọn image cũ ──
        stage('Cleanup Docker Images') {
            when { expression { stageEnabled('cleanup') } }
            steps {
                script {
                    def registry = REGISTRY_BASE
                    def fmt = '{{.CreatedAt}}|{{.ID}}'
                    sh "docker images '${IMAGE_BACKEND}' --format '${fmt}' | sort | head -n -3 | cut -d'|' -f2 | xargs -r docker rmi -f 2>/dev/null || true"
                    sh "docker images '${IMAGE_FRONTEND}' --format '${fmt}' | sort | head -n -3 | cut -d'|' -f2 | xargs -r docker rmi -f 2>/dev/null || true"
                    sh "docker system prune -f --filter 'until=24h' 2>/dev/null || true"
                    echo '>>> Đã dọn image cũ (giữ 3 mới nhất)'
                }
            }
        }

        // ── Deploy — đẩy nhanh ArgoCD sync ──
        //   MẶC ĐỊNH TẮT — bật bằng "deploy" trong ENABLED_STAGES.
        //   Có argocd CLI → sync ngay; không có → ArgoCD tự sync qua webhook/poll như bình thường.
        stage('Deploy (ArgoCD sync)') {
            when { expression { params.MODE != 'ci' && !isWebhookTrigger() && stageEnabled('deploy') } }
            steps {
                script {
                    if (sh(script: 'command -v argocd >/dev/null 2>&1', returnStatus: true) == 0) {
                        sh "argocd app sync ${params.PROJECT_NAME}-${env.ACTIVE_ENV} --async || echo 'ArgoCD sync lỗi (bỏ qua — ArgoCD tự sync)'; true"
                        echo '>>> Đã trigger ArgoCD sync'
                    } else {
                        echo '>>> argocd CLI không có — ArgoCD tự sync qua webhook/poll (bình thường)'
                    }
                }
            }
        }

        // ── Commit GitOps manifest — ArgoCD đọc là tự deploy ──
        stage('Commit GitOps Manifest') {
            when { expression { params.MODE != 'ci' && !isWebhookTrigger() && stageEnabled('gitops') && (params.MODE == 'release' || env.BUILD_FRONTEND != 'false' || env.BUILD_BACKEND != 'false') } }
            steps {
                dir('deploy-web') {
                    script {
                        // release mode → GitOps trỏ tới tag CÓ SẴN.
                        //   Ưu tiên: IMAGE_TAG_OVERRIDE_BACKEND/FRONTEND (riêng từng service) > IMAGE_TAG_OVERRIDE (chung)
                        //   Bỏ trống 1 service → không cập nhật service đó (giữ nguyên tag hiện tại)
                        def effectiveTag = (params.MODE == 'release' && params.IMAGE_TAG_OVERRIDE) ? params.IMAGE_TAG_OVERRIDE : env.IMAGE_TAG
                        def commitAuthor = 'release'
                        if (params.MODE != 'release') {
                            commitAuthor = sh(
                                script: 'cd ../app-source && git log -1 --format="%an <%ae>"',
                                returnStdout: true
                            ).trim()
                        }
                        def frontendTag = ''
                        def backendTag = ''
                        if (env.BUILD_BACKEND != 'false') {
                            def bTag = (params.MODE == 'release') ? (params.IMAGE_TAG_OVERRIDE_BACKEND ?: params.IMAGE_TAG_OVERRIDE) : effectiveTag
                            if (bTag) backendTag = "${IMAGE_BACKEND}:${bTag}"
                        }
                        if (env.BUILD_FRONTEND != 'false') {
                            def fTag = (params.MODE == 'release') ? (params.IMAGE_TAG_OVERRIDE_FRONTEND ?: params.IMAGE_TAG_OVERRIDE) : effectiveTag
                            if (fTag) frontendTag = "${IMAGE_FRONTEND}:${fTag}"
                        }
                            def argocdFile = "helm/${params.PROJECT_NAME}/.argocd-source-${params.PROJECT_NAME}-${ACTIVE_ENV}.yaml"

                            // ── Merge .argocd-source: chỉ cập nhật image được build, GIỮ NGUYÊN phần còn lại ──
                            // (không dùng new File() — bị Groovy sandbox chặn; dùng readFile/fileExists thay thế)
                            def imgLines = []
                            if (fileExists(argocdFile)) {
                                imgLines = readFile(argocdFile).readLines()
                            }
                            def keysToUpdate = []
                            if (backendTag) keysToUpdate << 'images.backend'
                            if (frontendTag) keysToUpdate << 'images.frontend'

                            def merged = []
                            def drop = 0
                            imgLines.each { line ->
                                if (drop > 0) { drop--; return }   // skip 2 dòng 'value' + 'forcestring' của block cũ
                                def nameMatch = (line =~ /^\s*- name:\s+(\S+)/)
                                if (nameMatch.find()) {
                                    if (nameMatch.group(1) in keysToUpdate) {
                                        drop = 2
                                        return
                                    }
                                }
                                merged << line
                            }
                            if (merged.isEmpty()) {
                                merged = ['helm:', '  parameters:']
                            }
                            if (backendTag) merged += ["  - name: images.backend", "    value: ${backendTag}", "    forcestring: true"]
                            if (frontendTag) merged += ["  - name: images.frontend", "    value: ${frontendTag}", "    forcestring: true"]
                            writeFile file: argocdFile, text: merged.join('\n') + '\n'
                            sh """
                                git config user.email "jenkins@${params.PROJECT_NAME}.local"
                                git config user.name "jenkins-ci"
                                git add ${argocdFile}
                                git diff --cached --quiet && echo "No changes to commit" || {
                                    git commit -m "deploy ${effectiveTag} by ${commitAuthor} (build #${BUILD_NUMBER}) [skip ci]"
                                    # Token GitHub nạp từ Vault (secret/ci/github) qua git credential helper
                                    # — không nhúng token vào URL/log
                                    git remote set-url origin https://github.com/vinh25042005/deploy-web.git
                                    # Pull ĐÚNG branch deploy (không phải origin/HEAD=main) + fail loud nếu conflict
                                    git pull --rebase origin ${params.DEPLOY_BRANCH} || { echo 'ERROR: git pull --rebase thất bại (conflict?)'; exit 1; }
                                    git push origin HEAD:${params.DEPLOY_BRANCH}
                                    echo "✅ Pushed tag ${IMAGE_TAG} to Git"
                                }
                            """
                        }
                }
            }
        }

    }

    post {
        success { echo "✅ CI thành công [${params.MODE}]! ArgoCD sẽ deploy ${ACTIVE_ENV} @ ${IMAGE_TAG}" }
        failure { echo "❌ CI thất bại!" }
        always {
            script {
                dir('app-source') {
                    script {
                        def registry = REGISTRY_BASE
                        def formatStr = '{{.CreatedAt}}|{{.ID}}'
                        sh "echo '>>> Cleaning old Docker images (keep newest 3)...'"
                        sh "docker images '${IMAGE_BACKEND}' --format '${formatStr}' | sort | head -n -3 | cut -d'|' -f2 | xargs -r docker rmi -f 2>/dev/null || true"
                        sh "docker images '${IMAGE_FRONTEND}' --format '${formatStr}' | sort | head -n -3 | cut -d'|' -f2 | xargs -r docker rmi -f 2>/dev/null || true"
                        sh "docker system prune -f --filter 'until=24h' 2>/dev/null || true"
                        sh "echo '>>> Cleanup done'"
                    }
                }
                cleanWs()  // Xóa workspace giải phóng disk
                // Dọn secret artifacts khỏi home Jenkins (git credential store + vault token)
                sh 'rm -f ~/.git-credentials ~/.vault-token 2>/dev/null || true'
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// [All-in-one] Helpers: MODE & ENABLED_STAGES gating
//   - parseEnabledStages: hỗ trợ JSON array HOẶC CSV
//   - stageEnabled(key):   stage có trong ENABLED_STAGES hay không
// ═══════════════════════════════════════════════════════════════════════════
@groovy.transform.Field
Set<String> enabledStages = []

def parseEnabledStages(String raw) {
    raw = raw?.trim() ?: ''
    if (raw.startsWith('[')) {
        return new groovy.json.JsonSlurper().parseText(raw) as Set<String>
    }
    return raw.split(',').collect { it.trim() } as Set<String>
}

def stageEnabled(String key) {
    return enabledStages.contains(key)
}

// [All-in-one] Phát hiện build tự trigger từ webhook (Generic Webhook Trigger).
//   Push code → chỉ chạy CI, KHÔNG commit GitOps / không deploy.
//   Deploy chỉ khi build TAY (Build with Parameters).
def isWebhookTrigger() {
    try {
        return currentBuild.getBuildCauses().any {
            def cls = it.getClass().getSimpleName().toLowerCase()
            return cls.contains('generic')
        }
    } catch (Throwable e) {
        return false
    }
}
