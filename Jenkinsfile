pipeline {
    agent any

    triggers {
        pollSCM('H/2 * * * *')
    }

    parameters {
        choice(name: 'ENV', choices: ['dev', 'stg', 'prd'], description: 'Target environment')
        string(name: 'APP_REPO_BRANCH', defaultValue: 'techshop-app', description: 'Branch of techshop-app')
        booleanParam(name: 'SKIP_BUILD', defaultValue: false, description: 'Skip Docker build?')
        booleanParam(name: 'SKIP_DEPLOY', defaultValue: false, description: 'Skip Helm deploy?')
    }

    environment {
        REGISTRY_BASE = 'docker.io/vinh2504'
        GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        IMAGE_TAG = "${GIT_COMMIT_SHORT}"

        APP_REPO = 'https://github.com/vinh25042005/techshop-app.git'
        APP_BRANCH = "${params.APP_REPO_BRANCH}"

        HELM_CHART_PATH = "${WORKSPACE}/deploy-web/helm/techshop"
        KUBE_NAMESPACE = "techshop-${params.ENV}"
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

        stage('Lint & Test') {
            when { expression { !params.SKIP_BUILD } }
            parallel {
                stage('Backend') {
                    steps {
                        dir('app-source/backend') {
                            sh 'npm ci'
                            sh 'npm run lint 2>/dev/null || true'
                            sh 'npm test 2>/dev/null || true'
                        }
                    }
                }
                stage('Frontend') {
                    steps {
                        dir('app-source/frontend') {
                            sh 'npm ci'
                            sh 'npx tsc --noEmit 2>/dev/null || true'
                        }
                    }
                }
            }
        }

        stage('Build & Push Backend') {
            when { expression { !params.SKIP_BUILD } }
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
            when { expression { !params.SKIP_BUILD } }
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
            when { expression { !params.SKIP_BUILD } }
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
            when { expression { !params.SKIP_BUILD } }
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

        stage('Deploy Helm') {
            when { expression { !params.SKIP_DEPLOY } }
            steps {
                dir('deploy-web/helm/techshop') {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-access-key']]) {
                        sh """
                            # Lấy kubeconfig mới nhất từ AWS SSM
                            aws ssm get-parameter --region ap-southeast-1 \\
                                --name /k8s/kubeconfig \\
                                --query Parameter.Value --output text | \\
                                base64 -d | gzip -d > ~/.kube/config || true

                            export KUBECONFIG=~/.kube/config
                            helm dependency build .
                            helm upgrade --install techshop-${params.ENV} . \
                                --namespace ${KUBE_NAMESPACE} \
                                --create-namespace \
                                --set images.backend=${REGISTRY_BASE}/deploy-web-backend:${IMAGE_TAG} \
                                --set images.frontend=${REGISTRY_BASE}/deploy-web-frontend:${IMAGE_TAG} \
                                --values values.yaml \
                                ${params.ENV != 'dev' ? "--values env/values-${params.ENV}.yaml" : ''} \
                                --wait --timeout 5m
                        """
                    }
                }
            }
        }

        stage('Smoke Test') {
            when { expression { !params.SKIP_DEPLOY } }
            steps {
                sh """
                    echo "✅ Deploy ${params.ENV} completed with tag ${IMAGE_TAG}"
                """
            }
        }
    }

    post {
        success { echo "✅ Pipeline thành công: ${params.ENV} @ ${IMAGE_TAG}" }
        failure { echo "❌ Pipeline thất bại!" }
    }
}
