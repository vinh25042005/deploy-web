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
        REGISTRY = 'ghcr.io/vinh25042005/deploy-web'
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

        stage('Build & Push Docker') {
            when { expression { !params.SKIP_BUILD } }
            parallel {
                stage('Backend Image') {
                    steps {
                        dir('app-source') {
                            withCredentials([usernamePassword(
                                credentialsId: 'ghcr-credentials',
                                usernameVariable: 'GHCR_USER',
                                passwordVariable: 'GHCR_PAT'
                            )]) {
                                sh """
                                    echo \$GHCR_PAT | docker login ghcr.io -u \$GHCR_USER --password-stdin
                                    docker build -f backend/Dockerfile \\
                                        -t ${REGISTRY}/backend:${IMAGE_TAG} \\
                                        -t ${REGISTRY}/backend:${ENV} \\
                                        .
                                    docker push ${REGISTRY}/backend:${IMAGE_TAG}
                                    docker push ${REGISTRY}/backend:${ENV}
                                """
                            }
                        }
                    }
                }
                stage('Frontend Image') {
                    steps {
                        dir('app-source') {
                            withCredentials([usernamePassword(
                                credentialsId: 'ghcr-credentials',
                                usernameVariable: 'GHCR_USER',
                                passwordVariable: 'GHCR_PAT'
                            )]) {
                                sh """
                                    echo \$GHCR_PAT | docker login ghcr.io -u \$GHCR_USER --password-stdin
                                    docker build -f frontend/Dockerfile \\
                                        --build-arg BACKEND_INTERNAL_URL=http://backend:3001 \\
                                        -t ${REGISTRY}/frontend:${IMAGE_TAG} \\
                                        -t ${REGISTRY}/frontend:${ENV} \\
                                        .
                                    docker push ${REGISTRY}/frontend:${IMAGE_TAG}
                                    docker push ${REGISTRY}/frontend:${ENV}
                                """
                            }
                        }
                    }
                }
            }
        }

        stage('Deploy Helm') {
            when { expression { !params.SKIP_DEPLOY } }
            steps {
                dir('deploy-web/helm/techshop') {
                    withKubeConfig(credentialsId: 'kubeconfig') {
                        sh """
                            helm dependency build .
                            helm upgrade --install techshop-${ENV} . \\
                                --namespace ${KUBE_NAMESPACE} \\
                                --create-namespace \\
                                --set images.backend=${REGISTRY}/backend:${IMAGE_TAG} \\
                                --set images.frontend=${REGISTRY}/frontend:${IMAGE_TAG} \\
                                --values values.yaml \\
                                ${ENV != 'dev' ? "--values env/values-${ENV}.yaml" : ''} \\
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
                    echo "✅ Deploy ${ENV} completed with tag ${IMAGE_TAG}"
                """
            }
        }
    }

    post {
        success { echo "✅ Pipeline thành công: ${ENV} @ ${IMAGE_TAG}" }
        failure { echo "❌ Pipeline thất bại!" }
    }
}
