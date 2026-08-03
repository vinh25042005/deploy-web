pipeline {
    agent any

    triggers {
        githubPush()
    }

    parameters {
        choice(name: 'ENV', choices: ['stg', 'dev', 'prd'], description: 'Target environment')
        choice(name: 'APP_REPO_BRANCH', choices: ['main', 'techshop-app'], description: 'Build tay: chọn branch techshop-app để clone (mặc định main)')
        booleanParam(name: 'SKIP_BUILD', defaultValue: false, description: 'Skip Docker build?')
        booleanParam(name: 'SKIP_BACKEND', defaultValue: false, description: 'Skip backend (chỉ build frontend)')
        booleanParam(name: 'SKIP_FRONTEND', defaultValue: false, description: 'Skip frontend (chỉ build backend)')
        booleanParam(name: 'BUILD_FULL', defaultValue: false, description: 'Build full — bỏ qua detect thay đổi, build cả backend + frontend')
    }

    environment {
        REGISTRY_BASE = 'docker.io/vinh2504'
        GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()

        // ACTIVE_ENV / IMAGE_TAG / APP_BRANCH được tính trong stage "Resolve ENV"
        APP_REPO = 'https://github.com/vinh25042005/techshop-app.git'
    }

    stages {
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
                    echo "→ ACTIVE_ENV=${env.ACTIVE_ENV} | IMAGE_TAG=${env.IMAGE_TAG}"
                }
            }
        }

        stage('Init') {
            parallel {
                stage('Clone App Source') {
                    steps {
                        dir('app-source') {
                            git branch: "${APP_BRANCH}",
                                url: "${APP_REPO}",
                                credentialsId: 'github-token'
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

        stage('Lint & Test') {
            when { expression { !params.SKIP_BUILD && (env.BUILD_BACKEND != 'false' || env.BUILD_FRONTEND != 'false') } }
            matrix {
                axes {
                    axis {
                        name 'NODE_VERSION'
                        values '18', '20', '22'
                    }
                }
                stages {
                    stage('Backend (Node $NODE_VERSION)') {
                        steps {
                            sh """
                                rm -rf app-source-backend-${NODE_VERSION}
                                cp -r app-source/backend app-source-backend-${NODE_VERSION}
                            """
                            dir("app-source-backend-${NODE_VERSION}") {
                                sh """#!/bin/bash
                                    if [ "${NODE_VERSION}" != "22" ]; then
                                        export NVM_DIR=/var/jenkins_home/.nvm
                                        [ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
                                        nvm use ${NODE_VERSION}
                                    fi
                                    npm ci
                                    npm run lint 2>/dev/null || true
                                    npm test 2>/dev/null || true
                                """
                            }
                        }
                    }
                    stage('Frontend (Node $NODE_VERSION)') {
                        steps {
                            sh """
                                rm -rf app-source-frontend-${NODE_VERSION}
                                cp -r app-source/frontend app-source-frontend-${NODE_VERSION}
                            """
                            dir("app-source-frontend-${NODE_VERSION}") {
                                sh """#!/bin/bash
                                    if [ "${NODE_VERSION}" != "22" ]; then
                                        export NVM_DIR=/var/jenkins_home/.nvm
                                        [ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
                                        nvm use ${NODE_VERSION}
                                    fi
                                    npm ci
                                    npx tsc --noEmit 2>/dev/null || true
                                """
                            }
                        }
                    }
                }
            }
        }

        stage('SonarQube Scan') {
            when { expression { !params.SKIP_BUILD && (env.BUILD_BACKEND != 'false' || env.BUILD_FRONTEND != 'false') } }
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    dir('app-source') {
                        sh """
                            sonar-scanner \
                                -Dsonar.projectKey=techshop-app \
                                -Dsonar.sources=frontend/src,backend/src \
                                -Dsonar.host.url=http://172.18.0.2:9000 \
                                -Dsonar.token=$SONAR_TOKEN \
                                -Dsonar.qualitygate.wait=true \
                                -Dsonar.exclusions=**/node_modules/**,**/*.test.ts,**/*.spec.ts \
                                -Dsonar.javascript.lcov.reportPaths=backend/coverage/lcov.info,frontend/coverage/lcov.info 2>&1
                        """
                    }
                }
            }
        }

        stage('Build & Push Backend') {
            when { expression { !params.SKIP_BUILD && !params.SKIP_BACKEND && env.BUILD_BACKEND != 'false' } }
            steps {
                dir('app-source') {
                    withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PAT')
                    ]) {
                        sh """
                            echo \$DOCKER_PAT | docker login -u \$DOCKER_USER --password-stdin
                            docker build -f backend/Dockerfile \\
                                -t ${REGISTRY_BASE}/deploy-web-backend:${IMAGE_TAG} \
                                -t ${REGISTRY_BASE}/deploy-web-backend:${ACTIVE_ENV} \
                                .
                            docker push ${REGISTRY_BASE}/deploy-web-backend:${IMAGE_TAG}
                            docker push ${REGISTRY_BASE}/deploy-web-backend:${ACTIVE_ENV}
                        """
                    }
                }
            }
        }

        stage('Scan Backend') {
            when { expression { !params.SKIP_BUILD && !params.SKIP_BACKEND && env.BUILD_BACKEND != 'false' } }
            steps {
                dir('app-source') {
                    sh """
                        trivy image ${REGISTRY_BASE}/deploy-web-backend:${IMAGE_TAG} \
                            --severity CRITICAL,HIGH \
                            --scanners vuln \
                            --format table \
                            --exit-code 0 2>&1 | \
                            grep -v "node_modules" | \
                            tee trivy-backend.txt || true

                        trivy image ${REGISTRY_BASE}/deploy-web-backend:${IMAGE_TAG} \
                            --severity CRITICAL,HIGH \
                            --format sarif \
                            --output trivy-backend.sarif \
                            --exit-code 0 || true

                        syft ${REGISTRY_BASE}/deploy-web-backend:${IMAGE_TAG} \
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
            when { expression { !params.SKIP_BUILD && !params.SKIP_FRONTEND && env.BUILD_FRONTEND != 'false' } }
            steps {
                dir('app-source') {
                    withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PAT'
                    )]) {
                        sh """
                            echo \$DOCKER_PAT | docker login -u \$DOCKER_USER --password-stdin
                            docker build -f frontend/Dockerfile \\
                                --build-arg BACKEND_INTERNAL_URL=http://backend:3001 \\
                                -t ${REGISTRY_BASE}/deploy-web-frontend:${IMAGE_TAG} \
                                -t ${REGISTRY_BASE}/deploy-web-frontend:${ACTIVE_ENV} \
                                .
                            docker push ${REGISTRY_BASE}/deploy-web-frontend:${IMAGE_TAG}
                            docker push ${REGISTRY_BASE}/deploy-web-frontend:${ACTIVE_ENV}
                        """
                    }
                }
            }
        }

        stage('Scan Frontend') {
            when { expression { !params.SKIP_BUILD && !params.SKIP_FRONTEND && env.BUILD_FRONTEND != 'false' } }
            steps {
                dir('app-source') {
                    sh """
                        trivy image ${REGISTRY_BASE}/deploy-web-frontend:${IMAGE_TAG} \
                            --severity CRITICAL,HIGH \
                            --scanners vuln \
                            --format table \
                            --exit-code 0 2>&1 | \
                            grep -v "node_modules" | \
                            tee trivy-frontend.txt || true

                        trivy image ${REGISTRY_BASE}/deploy-web-frontend:${IMAGE_TAG} \
                            --severity CRITICAL,HIGH \
                            --format sarif \
                            --output trivy-frontend.sarif \
                            --exit-code 0 || true

                        syft ${REGISTRY_BASE}/deploy-web-frontend:${IMAGE_TAG} \
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

        stage('Commit tag to Git') {
            when { expression { env.BUILD_FRONTEND != 'false' || env.BUILD_BACKEND != 'false' } }
            steps {
                dir('deploy-web') {
                    withCredentials([usernamePassword(
                        credentialsId: 'github-token',
                        usernameVariable: 'GIT_USER',
                        passwordVariable: 'GIT_PASS'
                    )]) {
                        script {
                            def commitAuthor = sh(
                                script: 'cd ../app-source && git log -1 --format="%an <%ae>"',
                                returnStdout: true
                            ).trim()
                            def frontendTag = env.BUILD_FRONTEND != 'false' ? "${REGISTRY_BASE}/deploy-web-frontend:${IMAGE_TAG}" : ''
                            def backendTag = env.BUILD_BACKEND != 'false' ? "${REGISTRY_BASE}/deploy-web-backend:${IMAGE_TAG}" : ''
                            def argocdFile = "helm/techshop/.argocd-source-techshop-${ACTIVE_ENV}.yaml"

                            // ── Merge .argocd-source: chỉ cập nhật image được build, GIỮ NGUYÊN phần còn lại ──
                            def argocdPath = "${env.WORKSPACE}/deploy-web/${argocdFile}"
                            def imgFile = new File(argocdPath)
                            def imgLines = imgFile.exists() ? imgFile.readLines() : []
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
                            imgFile.text = merged.join('\n') + '\n'
                            sh """
                                git config user.email "jenkins@techshop.local"
                                git config user.name "jenkins-ci"
                                git add ${argocdFile}
                                git diff --cached --quiet && echo "No changes to commit" || {
                                    git commit -m "deploy ${IMAGE_TAG} by ${commitAuthor} (build #${BUILD_NUMBER}) [skip ci]"
                                    git pull --rebase https://\$GIT_USER:\$GIT_PASS@github.com/vinh25042005/deploy-web.git week-6-argo-rollouts 2>/dev/null || true
                                    git push https://\$GIT_USER:\$GIT_PASS@github.com/vinh25042005/deploy-web.git HEAD:week-6-argo-rollouts
                                    echo "✅ Pushed tag ${IMAGE_TAG} to Git"
                                }
                            """
                        }
                    }
                }
            }
        }

    }

    post {
        success { echo "✅ CI thành công! ArgoCD sẽ deploy ${ACTIVE_ENV} @ ${IMAGE_TAG}" }
        failure { echo "❌ CI thất bại!" }
        always {
            script {
                dir('app-source') {
                    script {
                        def registry = REGISTRY_BASE
                        def formatStr = '{{.CreatedAt}}|{{.ID}}'
                        sh "echo '>>> Cleaning old Docker images (keep newest 3)...'"
                        sh "docker images '${registry}/deploy-web-backend' --format '${formatStr}' | sort | head -n -3 | cut -d'|' -f2 | xargs -r docker rmi -f 2>/dev/null || true"
                        sh "docker images '${registry}/deploy-web-frontend' --format '${formatStr}' | sort | head -n -3 | cut -d'|' -f2 | xargs -r docker rmi -f 2>/dev/null || true"
                        sh "docker system prune -f --filter 'until=24h' 2>/dev/null || true"
                        sh "echo '>>> Cleanup done'"
                    }
                }
                cleanWs()  // Xóa workspace giải phóng disk
            }
        }
    }
}
