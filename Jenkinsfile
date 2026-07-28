pipeline {
    agent any

    triggers {
        githubPush()
    }

    parameters {
        choice(name: 'ENV', choices: ['dev', 'stg', 'prd'], description: 'Target environment')
        string(name: 'APP_REPO_BRANCH', defaultValue: 'techshop-app', description: 'Branch of techshop-app')
        booleanParam(name: 'SKIP_BUILD', defaultValue: false, description: 'Skip Docker build?')
        booleanParam(name: 'SKIP_BACKEND', defaultValue: false, description: 'Skip backend (chỉ build frontend)')
        booleanParam(name: 'SKIP_FRONTEND', defaultValue: false, description: 'Skip frontend (chỉ build backend)')
    }

    environment {
        REGISTRY_BASE = 'docker.io/vinh2504'
        GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        IMAGE_TAG = "${params.ENV}-${BUILD_NUMBER}"

        APP_REPO = 'https://github.com/vinh25042005/techshop-app.git'
        APP_BRANCH = "${params.APP_REPO_BRANCH}"
    }

    stages {
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
                        if (changed == 'first-build') {
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
                dir('app-source') {
                    sh """
                        sonar-scanner \
                            -Dsonar.projectKey=techshop-app \
                            -Dsonar.sources=frontend/src,backend/src \
                            -Dsonar.host.url=http://172.18.0.2:9000 \
                            -Dsonar.token=squ_a04035f1d3872eaf07d0d0a9f27e7b21946e24d9 \
                            -Dsonar.qualitygate.wait=false \
                            -Dsonar.exclusions=**/node_modules/**,**/*.test.ts,**/*.spec.ts \
                            -Dsonar.javascript.lcov.reportPaths=backend/coverage/lcov.info,frontend/coverage/lcov.info 2>&1 || true
                    """
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
                                -t ${REGISTRY_BASE}/deploy-web-backend:${params.ENV} \
                                .
                            docker push ${REGISTRY_BASE}/deploy-web-backend:${IMAGE_TAG}
                            docker push ${REGISTRY_BASE}/deploy-web-backend:${params.ENV}
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
                                -t ${REGISTRY_BASE}/deploy-web-frontend:${params.ENV} \
                                .
                            docker push ${REGISTRY_BASE}/deploy-web-frontend:${IMAGE_TAG}
                            docker push ${REGISTRY_BASE}/deploy-web-frontend:${params.ENV}
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
                            sh """
                                echo 'helm:' > helm/techshop/.argocd-source-techshop-dev.yaml
                                echo '  parameters:' >> helm/techshop/.argocd-source-techshop-dev.yaml
                            """
                            if (backendTag) {
                                sh """
                                    echo '  - name: images.backend' >> helm/techshop/.argocd-source-techshop-dev.yaml
                                    echo '    value: ${backendTag}' >> helm/techshop/.argocd-source-techshop-dev.yaml
                                    echo '    forcestring: true' >> helm/techshop/.argocd-source-techshop-dev.yaml
                                """
                            }
                            if (frontendTag) {
                                sh """
                                    echo '  - name: images.frontend' >> helm/techshop/.argocd-source-techshop-dev.yaml
                                    echo '    value: ${frontendTag}' >> helm/techshop/.argocd-source-techshop-dev.yaml
                                    echo '    forcestring: true' >> helm/techshop/.argocd-source-techshop-dev.yaml
                                """
                            }
                            sh """
                                git config user.email "jenkins@techshop.local"
                                git config user.name "jenkins-ci"
                                git add helm/techshop/.argocd-source-techshop-dev.yaml
                                git diff --cached --quiet && echo "No changes to commit" || {
                                    git commit -m "deploy ${IMAGE_TAG} by ${commitAuthor} (build #${BUILD_NUMBER})"
                                    git push https://\${GIT_USER}:\${GIT_PASS}@github.com/vinh25042005/deploy-web.git HEAD:capstone-week5
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
        success { echo "✅ CI thành công! ArgoCD sẽ deploy ${params.ENV} @ ${IMAGE_TAG}" }
        failure { echo "❌ CI thất bại!" }
        always {
            script {
                dir('app-source') {
                    sh """
                        echo '>>> Cleaning old Docker images (keep newest 3)...'
                        docker images '${REGISTRY_BASE}/deploy-web-backend' --format '{{.ID}}' | sort -u | tail -n +4 | xargs -r docker rmi -f 2>/dev/null || true
                        docker images '${REGISTRY_BASE}/deploy-web-frontend' --format '{{.ID}}' | sort -u | tail -n +4 | xargs -r docker rmi -f 2>/dev/null || true
                        docker system prune -f --filter 'until=24h' 2>/dev/null || true
                        echo '>>> Cleanup done'
                    """
                }
            }
        }
    }
}
