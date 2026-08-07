import groovy.json.JsonOutput

@groovy.transform.Field 
String ACTION_TYPE = 'FULL_CICD'

@groovy.transform.Field 
String pipelineBranchCode

pipeline {
  agent any
  parameters {
    string(name: 'IMAGETAG', defaultValue: '', description: 'The Docker image tag')
    string(name: 'TIMESTAMP', defaultValue: '', description: 'Timestamp of the build')
    string(name: 'COMMIT_NAME', defaultValue: '', description: 'The commit hash')
    string(name: 'COMMIT_MESSAGE', defaultValue: '', description: 'The commit message')
    string(name: 'PROJECT_NAME', defaultValue: '', description: 'Name of project')
    string(name: 'ENVIRONMENT', defaultValue: '', description: 'Environment name (e.g., dev, sit, release)')
    string(name: 'REPOSITORY_NAME', defaultValue: '', description: 'Repository name (e.g., release-image, sit, release)')
    string(name: 'LOCATION', defaultValue: '', description: 'Location run cicd (e.g, Company or Client)')
    string(name: 'PATH_NAME', defaultValue: '', description: 'Name of path')
    string(name: 'SOURCE_CODE_PATH', defaultValue: '', description: 'Name of path project')
    string(name: 'REGISTRY_URL', defaultValue: '', description: 'registry.gitlab.com')
    string(name: 'REGISTRY_AUTH', description: 'Credentials for Docker Registry')
    string(name: 'GITLAB_ACCESS_TOKEN', description: 'Credentials for source_code')
    string(name: 'BRANCH_CODE', defaultValue: '', description: 'Branch name (e.g., develop-release, sit-release, release-version)')
    string(name: 'COMPANY_VAULT_ADDR', defaultValue: '', description: 'Vault string url')
    string(name: 'COMPANY_VAULT_TOKEN', description: 'Credentials for Vault')
    string(name: 'VAULT_PATH', defaultValue: '', description: 'Vault path')
    string(name: 'JENKINS_CLIENT_URL', defaultValue: '', description: 'URL of Jenkins client job (e.g., jenkins.example.com)')
    string(name: 'JENKINS_CLIENT_USER', defaultValue: '', description: 'Username of Jenkins client')
    string(name: 'JENKINS_CLIENT_TOKEN', defaultValue: '', description: 'API token of Jenkins client user')
    string(name: 'COMPANY_SECRET_VAULT', defaultValue: '["DOCKER_FILE","GRUNTFILE"]', description: 'Secret form vault flags array')
    string(name: 'COMPANY_LOCATION_VAULT', defaultValue: '["Dockerfile","Gruntfile.js"]', description: 'Location path form vault flags array')
    string(name: 'ENABLED_STAGES', defaultValue: '["CheckSource", "GetVault"]', description: 'Comma-separated list of enabled stages')
    string(name: 'NODEJS_VERSION', defaultValue: 'NodeJS_18', description: 'NodeJs version')
    string(name: 'TEAMS_WEBHOOK_URL', defaultValue: '', description: 'Teams webhook url')

    // [MERGE] Feature Modularization Parameter
    string(name: 'MODULE_DEPLOY', defaultValue: '', description: 'Modules will deploy (e.g., backend,frontend,integration')

    //Client information
    string(name: 'CLIENT_ENV_ACTION', defaultValue: '', description: 'Action environment (e.g., sit, uat)')
    string(name: 'CLIENT_LOCATION', defaultValue: '', description: 'Location run cicd (e.g, Company or Client)')
    string(name: 'CLIENT_ENABLED_STAGES', defaultValue: '["GetReleaseVersion"]', description: 'Comma-separated list of enabled stages')
    string(name: 'CLIENT_SECRET_VAULT', defaultValue: '["ENV_FILE","CONFIG_ENV"]', description: 'Secret form vault flags array')
    string(name: 'CLIENT_SECRET_NAME', defaultValue: '["env-file-secret", "config-env-secret"]', description: 'Name secret form vault flags array')
    string(name: 'CLIENT_LOCATION_VAULT', defaultValue: '["sit.js","configEnv.js"]', description: 'Location path form vault flags array')

    //Enable stage for environment
    string(name: 'DC_ENABLED_STAGES', defaultValue: '["GetReleaseVersion"]', description: 'Comma-separated list of enabled stages')
    string(name: 'DR_ENABLED_STAGES', defaultValue: '["GetReleaseVersion"]', description: 'Comma-separated list of enabled stages')
    //DC information
    string(name: 'DC_KUBE_CONFIG_FILE', defaultValue: '', description: 'Kube config file of client')
    string(name: 'DC_VAULT_ADDR', defaultValue: '', description: 'Vault string url')
    string(name: 'DC_VAULT_TOKEN', description: 'Credentials for Vault')
    string(name: 'DC_JENKINS_URL', defaultValue: '', description: 'URL of Jenkins client job (e.g., jenkins.example.com)')
    string(name: 'DC_JENKINS_USER', defaultValue: '', description: 'Username of Jenkins client')
    string(name: 'DC_JENKINS_TOKEN', defaultValue: '', description: 'API token of Jenkins client user')
    //DR information
    string(name: 'DR_KUBE_CONFIG_FILE', defaultValue: '', description: 'Kube config file of client')
    string(name: 'DR_VAULT_ADDR', defaultValue: '', description: 'Vault string url')
    string(name: 'DR_VAULT_TOKEN', description: 'Credentials for Vault')
    string(name: 'DR_JENKINS_URL', defaultValue: '', description: 'URL of Jenkins client job (e.g., jenkins.example.com)')
    string(name: 'DR_JENKINS_USER', defaultValue: '', description: 'Username of Jenkins client')
    string(name: 'DR_JENKINS_TOKEN', defaultValue: '', description: 'API token of Jenkins client user')

    // External information
    string(name: 'ERP_URL', defaultValue: '', description: 'String URL of ERP next')
    string(name: 'ERP_IP_ADDR', defaultValue: '', description: 'IP address server of ERP next')
    string(name: 'ERP_SSH_KEY', defaultValue: '', description: 'SSH-KEY server of ERP next')
    string(name: 'ERP_SSH_PORT', defaultValue: '', description: 'SSH-PORT server of ERP next')
    string(name: 'ERP_APP_NAME', defaultValue: '', description: 'ERPNEXT app name')
  }
  environment {
    PATH = "${params.NODEJS_VERSION}/bin:${PATH}" //Node Version
    TEAMS_WEBHOOK_URL = "${params.TEAMS_WEBHOOK_URL}" //Teams_webhook
  }

  // ---------------------------- Notification when starting pipeline ---------------------------
  stages {
    stage('Initialization') {
      steps {
        script { runInitialization() }
      }
    }
    // ---------------------------- Select Execution Mode (for uat/prod) ---------------------------
    stage('Select Execution Mode') {
      when {
        expression {
          (params.ENVIRONMENT == 'uat' || params.ENVIRONMENT == 'prod') &&
           params.LOCATION.contains('company-side')
        }
      }
      steps {
        script { runSelectExecutionMode() }
      }
    }
    // --------------------------- Get release version information --------------------------------
    stage('Get release version information') {
      steps {
        script { runGetReleaseVersionInfo() }
      }
    }
    // --------------------------------------------------------------------------------------------
    // ---------------------------------- Process Company side ------------------------------------
    // --------------------------------------------------------------------------------------------

    // ---------------------------------- Checkout source code ------------------------------------
    stage('Checkout Source code') {
      steps {
        script {
          if (ACTION_TYPE == 'FULL_CICD') {
            if (params.LOCATION.contains('company-side')) {
              runCheckoutSourceCode()
            } else {
              echo "Skipping stage: Not company-side."
            }
          } else {
            echo "Skipping 'Checkout Source code' as ACTION_TYPE is ${ACTION_TYPE}"
          }
        }
      }
    }
    // --------------------------- Get secrets from Vault -----------------------------------------
    stage('Get secrets from Vault') {
      steps {
        script {
          // Logic CD (client-side)
          if (params.CLIENT_LOCATION.contains('client-side') && params.CLIENT_ENV_ACTION.contains('client-deploy') &&
            (params.CLIENT_ENABLED_STAGES.contains('get-vault-dc') ||
              params.CLIENT_ENABLED_STAGES.contains('get-vault-dr') ||
              params.CLIENT_ENABLED_STAGES.contains('company-get-vault'))) {
            
            runGetSecretsFromVault()

          // Logic CI (company-side)
          } else if (ACTION_TYPE == 'FULL_CICD' && params.LOCATION.contains('company-side') && params.ENABLED_STAGES.contains('company-get-vault')) {
            runGetSecretsFromVault()
          
          } else {
            echo "Skipping 'Get secrets from Vault' (company-side) as ACTION_TYPE is ${ACTION_TYPE}"
          }
        }
      }
    }

    // ----------------[MERGE] Feature Modularization Stage ---------------------------------------
    stage('Process package.json and dependencies') {
      steps {
        script {
            // Stage này cũng phải tuân thủ ACTION_TYPE == FULL_CICD
            if (ACTION_TYPE == 'FULL_CICD') {
                if (params.LOCATION.contains('company-side') &&
                   (params.MODULE_DEPLOY.contains('backend') || params.MODULE_DEPLOY.contains('frontend'))) {
                    
                    runProcessPackageJson()

                } else {
                    echo "Skipping Process package.json: Not company-side or MODULE_DEPLOY empty/invalid."
                }
            } else {
                echo "Skipping 'Process package.json' as ACTION_TYPE is ${ACTION_TYPE}"
            }
        }
      }
    }
    // --------------------------------------------------------------------------------------------

    // -------------------------------- Grunt source ----------------------------------------------
    stage('Grunt source') {
      steps {
        script {
          if (ACTION_TYPE == 'FULL_CICD') {
            if (params.LOCATION.contains('company-side') &&
                (params.ENABLED_STAGES.contains('grunt-backend') || params.ENABLED_STAGES.contains('grunt-frontend'))) {
              runGruntSource()
            } else {
              echo "Skipping stage: Grunt not enabled or not company-side."
            }
          } else {
            echo "Skipping 'Grunt source' as ACTION_TYPE is ${ACTION_TYPE}"
          }
        }
      }
    }
    // ------------------------------ Build and push image ----------------------------------------
    stage('Build and push image') {
      steps {
        script {
          if (ACTION_TYPE == 'FULL_CICD') {
            if (params.LOCATION.contains('company-side') &&
                (params.ENABLED_STAGES.contains('build-push') || params.ENABLED_STAGES.contains('build-config-push'))) {
              runBuildAndPushImage()
            } else {
              echo "Skipping stage: Build not enabled or not company-side."
            }
          } else {
            echo "Skipping 'Build and push image' as ACTION_TYPE is ${ACTION_TYPE}"
          }
        }
      }
    }

    // ------------------------------ Clean old docker images -------------------------------------
    stage('Clean old docker images') {
      steps {
        script {
          if (ACTION_TYPE == 'FULL_CICD') {
            if (params.LOCATION.contains('company-side') &&
                params.ENABLED_STAGES.contains('clean-image')) {
              runCleanOldDockerImages()
            } else {
              echo "Skipping stage: Clean-image not enabled or not company-side."
            }
          } else {
            echo "Skipping 'Clean old docker images' as ACTION_TYPE is ${ACTION_TYPE}"
          }
        }
      }
    }
    // --------------------------------- Trigger CD client ----------------------------------------
    stage('Trigger CD client') {
      when {
        expression {
          (params.LOCATION.contains('company-side') && params.ENABLED_STAGES.contains('trigger-cd'))
        }
      }
      steps {
        script { runTriggerCDClient() }
      }
    }
    // --------------------------------------------------------------------------------------------
    // ---------------------------------- Process Client side -------------------------------------
    // --------------------------------------------------------------------------------------------

    stage('Apply Secrets') {
      when {
        expression {
          return params.CLIENT_LOCATION.contains('client-side') &&
            params.CLIENT_ENV_ACTION.contains('client-deploy') &&
            (params.CLIENT_ENABLED_STAGES.contains('secret-dc') ||
              params.CLIENT_ENABLED_STAGES.contains('secret-dr'))
        }
      }
      steps {
        script { runApplySecrets() }
      }
    }
    stage('Unit Test before deploy new version') {
        when {
            expression {
                return params.CLIENT_LOCATION.contains('client-side') &&
                        params.CLIENT_ENV_ACTION.contains('client-deploy') &&
                        (params.CLIENT_ENABLED_STAGES.contains('unit-test-dc') || params.CLIENT_ENABLED_STAGES.contains('unit-test-dr'))
            }
        }
        steps {
            script { runUnitTest() }
        }
      }
    stage('Deploy to Cluster') {
        when {
            expression {
                return params.CLIENT_LOCATION.contains('client-side') &&
                        params.CLIENT_ENV_ACTION.contains('client-deploy') &&
                        (params.CLIENT_ENABLED_STAGES.contains('deploy-dc') ||
                        params.CLIENT_ENABLED_STAGES.contains('deploy-dr') ||
                        params.CLIENT_ENABLED_STAGES.contains('deploy-erp'))
            }
        }
        steps {
            script { runDeployToCluster() }
        }
    }
    stage('Apply configure to DC and DR') {
      when {
        expression {
          return params.CLIENT_LOCATION.contains('client-side') && params.CLIENT_ENV_ACTION.contains('client-deploy') &&
            (params.CLIENT_ENABLED_STAGES.contains('configure-dc') || params.CLIENT_ENABLED_STAGES.contains('configure-dr'))
        }
      }
      steps {
        script { runApplyConfigure() }
      }
    }
    stage('Trigger DC and DR deploy') {
        when {
            expression {
                return params.CLIENT_LOCATION.contains('client-side') && params.CLIENT_ENV_ACTION.contains('client-trigger') &&
                        (params.CLIENT_ENABLED_STAGES.contains('trigger-dc') ||
                        params.CLIENT_ENABLED_STAGES.contains('trigger-dr'))
            }
        }
        steps {
            script { runTriggerDCandDRDeploy() }
        }
    }
    stage('Replace vault pipeline') {
        when {
            expression {
                return params.CLIENT_LOCATION.contains('client-side') &&
                        params.CLIENT_ENV_ACTION.contains('client-deploy') &&
                        (params.CLIENT_ENABLED_STAGES.contains('replace-vault-pipeline'))
            }
        }
        steps {
            script { runReplaceVaultPipeline() }
            }
        }
    stage('Work Flow Process') {
        when {
            expression {
                return params.CLIENT_LOCATION.contains('client-side') &&
                        params.CLIENT_ENV_ACTION.contains('client-deploy') &&
                        (params.CLIENT_ENABLED_STAGES.contains('workflow-process-pipeline'))
            }
        }
        steps {
            script { runWorkFlowProcess() }
        }
    }
    // ----------------------------------------- END ----------------------------------------------
  }
  // ------------------------------------- Post actions -----------------------------------------
  post {
    success {
      script { runPostSuccess() }
    }
    failure {
      script { runPostFailure() }
    }
  }
  // --------------------------------------------------------------------------------------------
}

// --------------------------------------------------------------------------------------------
// ---------------------------- HÀM LOGIC CHO STAGES ------------------------------------
// --------------------------------------------------------------------------------------------

// Stage: Initialization
def runInitialization() {
  // Khởi tạo giá trị branch ngay lập tức khi pipeline bắt đầu
  pipelineBranchCode = params.BRANCH_CODE

  // Đặt danh tính build sớm nhất có thể — trước mọi input/stage khác
  // để Blue Ocean, Catalog, webhook, audit log đều thấy đúng tên ngay từ đầu
  currentBuild.displayName = "${params.PATH_NAME} - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.LOCATION} - Initialization"
  currentBuild.description = "Branch: ${params.BRANCH_CODE}"

  def initMessage = "Pipeline for ${params.PROJECT_NAME} ${params.ERP_APP_NAME} - ${params.ENVIRONMENT} - ${params.LOCATION} ${params.CLIENT_LOCATION} has been started."
  office365ConnectorSend message: initMessage, status: 'STARTED', webhookUrl: "${env.TEAMS_WEBHOOK_URL}"
}

// Stage: Select Execution Mode
def runSelectExecutionMode() {
  try {
    // Input 1 (trả về String)
    def selectedAction = input(
      id: 'actionChoice',
      message: "Môi trường UAT/PROD: Vui lòng chọn hành động:",
      parameters: [
        choice(
          name: 'ACTION',
          choices: ['FULL_CICD', 'TRIGGER_CD_ONLY'],
          description: 'FULL_CICD: Chạy đầy đủ CI (build, push ảnh) rồi trigger CD.\nTRIGGER_CD_ONLY: Bỏ qua CI, nhập tay thông tin để trigger CD.'
        )
      ]
    )

    // Gán vào biến toàn cục @Field
    ACTION_TYPE = selectedAction

    if (ACTION_TYPE == 'TRIGGER_CD_ONLY') {
      
      // Input 2 (trả về Map)
      def cdParams = input(
        id: 'cdParams',
        message: 'Nhập thông tin cho CD Trigger (dùng cho UAT/PROD):',
        parameters: [
          string(name: 'IMAGETAG', defaultValue: '', description: 'Full Image Tag để deploy (VD: registry.gitlab.com/neonstudio/path/project:sit-123)'),
          string(name: 'TIMESTAMP', defaultValue: new Date().format("HH:mm:ss'-'dd-MM-yyyy"), description: 'Timestamp (mặc định là bây giờ)'),
          string(name: 'COMMIT_NAME', defaultValue: 'manual', description: 'Commit hash (VD: lấy từ build SIT)'),
          string(name: 'COMMIT_MESSAGE', defaultValue: 'manual trigger', description: 'Commit message (VD: lấy từ build SIT)')
        ]
      )
      
      // Gán vào 'env' để stage 'Trigger CD client' dùng
      env.IMAGETAG = cdParams.get('IMAGETAG')
      env.TIMESTAMP = cdParams.get('TIMESTAMP')
      env.COMMIT_NAME = cdParams.get('COMMIT_NAME')
      env.COMMIT_MESSAGE = cdParams.get('COMMIT_MESSAGE')

      echo "TRIGGER_CD_ONLY: Đã ghi nhận ImageTag: ${env.IMAGETAG}"

    } else if (ACTION_TYPE == 'FULL_CICD') {
      
      // Input 3 (trả về String)
      def branchInput = input(
        id: 'branchInput',
        message: "Xác nhận Branch Code cho FULL_CICD:",
        parameters: [
          string(name: 'BRANCH_CODE', 
                 defaultValue: pipelineBranchCode, 
                 description: 'Nhập branch code để build. Mặc định là branch đã truyền vào.')
        ]
      )

      // Gán trực tiếp giá trị String trả về
      pipelineBranchCode = branchInput
      
      echo "FULL_CICD: Đã xác nhận, sẽ build từ branch: ${pipelineBranchCode}"
    }

  } catch (org.jenkinsci.plugins.workflow.steps.FlowInterruptedException e) {
    currentBuild.result = 'ABORTED'
    error("Build Aborted by user at selection step.")
  }
}

// Stage: Get release version information
def runGetReleaseVersionInfo() {
  currentBuild.displayName = "${params.PATH_NAME} - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.LOCATION} ${params.CLIENT_LOCATION} - ${STAGE_NAME}"
  try {
    detectOSType()
    displayCompanyInfo()
    displayClientInfo()
  } catch (Exception e) {
    captureStageError('Get release version information', e)
  }
}

// Stage: Checkout Source code
def runCheckoutSourceCode() {
  currentBuild.displayName = "${params.PATH_NAME} - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.LOCATION} - ${STAGE_NAME}"
  try {
    verifyGitlabToken()
    checkoutSourceCode()
    retrieveCommitDetails()
  } catch (Exception e) {
    captureStageError('Checkout Source code', e)
  }
}

// Stage: Get secrets from Vault
def runGetSecretsFromVault() {
  def vaultAddr = ""
  def vaultToken = ""
  def secretVault = []
  def locationVault = []

  if (params.CLIENT_ENABLED_STAGES.contains('get-vault-dc')) {
    vaultAddr = params.DC_VAULT_ADDR
    vaultToken = params.DC_VAULT_TOKEN
    secretVault = new groovy.json.JsonSlurper().parseText(params.CLIENT_SECRET_VAULT)
    locationVault = new groovy.json.JsonSlurper().parseText(params.CLIENT_LOCATION_VAULT)
    currentBuild.displayName = "DC - ${params.PATH_NAME} - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.CLIENT_LOCATION} - ${STAGE_NAME}"
  } else if (params.CLIENT_ENABLED_STAGES.contains('get-vault-dr')) {
    vaultAddr = params.DR_VAULT_ADDR
    vaultToken = params.DR_VAULT_TOKEN
    secretVault = new groovy.json.JsonSlurper().parseText(params.CLIENT_SECRET_VAULT)
    locationVault = new groovy.json.JsonSlurper().parseText(params.CLIENT_LOCATION_VAULT)
    currentBuild.displayName = "DR - ${params.PATH_NAME} - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.CLIENT_LOCATION} - ${STAGE_NAME}"
  } else if (params.LOCATION.contains('company-side') && params.ENABLED_STAGES.contains('company-get-vault')) {
    vaultAddr = params.COMPANY_VAULT_ADDR
    vaultToken = params.COMPANY_VAULT_TOKEN
    secretVault = new groovy.json.JsonSlurper().parseText(params.COMPANY_SECRET_VAULT)
    locationVault = new groovy.json.JsonSlurper().parseText(params.COMPANY_LOCATION_VAULT)
    currentBuild.displayName = "Company - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.LOCATION} - ${STAGE_NAME}"
  }

  try {
    withCredentials([string(credentialsId: vaultToken, variable: 'VAULT_TOKEN')]) {
      def vaultCommand = """
          vault login -no-print -address=${vaultAddr} ${VAULT_TOKEN}
          vault status -address ${vaultAddr}
      """
      if (env.OS_TYPE == 'linux') {
        sh vaultCommand
      } else {
        bat(script: vaultCommand, returnStdout: true)
      }

      for (int i = 0; i < secretVault.size(); i++) {
        def command = "vault kv get -field=${secretVault[i]} -address ${vaultAddr} ${params.VAULT_PATH}"
        def secret_value = ""

        if (env.OS_TYPE == 'linux') {
          secret_value = sh(
            script: command,
            returnStdout: true
          ).trim()
        } else {
          secret_value = powershell(
            script: command,
            returnStdout: true
          ).trim()
        }

        def file_path = "${params.PROJECT_NAME}-${params.ENVIRONMENT}/${locationVault[i]}"
        writeFile file: file_path, text: secret_value
      }
    }
  } catch (Exception e) {
    captureStageError('Get secrets from Vault', e)
  }
}

// [MERGE] Function runProcessPackageJson
def runProcessPackageJson() {
    try {
        def jsonFile = readJSON file: "${params.PROJECT_NAME}-${params.ENVIRONMENT}/package.json"
        echo "Modules to be released: ${jsonFile}"
        def baseModule = jsonFile.based
        def modules = jsonFile.modules
        def allModules = [:]
        def modulesToProcess = modules.keySet() as List

        echo "Modules to process: ${modulesToProcess}"

        processModules(modulesToProcess, allModules, modules, baseModule)

        def foldersToCopy = determineFoldersToCopy(params.MODULE_DEPLOY)
        mergeFiles(params.MODULE_DEPLOY, baseModule, allModules, params.PROJECT_NAME, params.ENVIRONMENT)
        copyFolders(allModules, baseModule, foldersToCopy, params.PROJECT_NAME, params.ENVIRONMENT)
        moveFolders(baseModule, params.PROJECT_NAME, params.ENVIRONMENT)
    } catch (Exception e) {
        captureStageError('Process package.json and dependencies', e)
    }
}

// Stage: Grunt source
def runGruntSource() {
  currentBuild.displayName = "${params.PATH_NAME} - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.LOCATION} - ${STAGE_NAME}"
  try {
    def gruntCommand = setupGruntEnvironment()
    if (params.ENABLED_STAGES.contains('grunt-backend')) {
      gruntCommand += runGruntBackend()
    }
    if (params.ENABLED_STAGES.contains('grunt-frontend')) {
      gruntCommand += runGruntFrontend()
    }
    gruntCommand += cleanup()
    if (env.OS_TYPE == 'linux') {
      sh gruntCommand
    } else {
      bat gruntCommand
    }
  } catch (Exception e) {
    captureStageError('Grunt source', e)
  }
}

// Stage: Build and push image
def runBuildAndPushImage() {
  currentBuild.displayName = "${params.PATH_NAME} - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.LOCATION} - ${STAGE_NAME}"
  try {
    prepareDockerConfig()

    def buildCommand = ''
    if (params.ENABLED_STAGES.contains('build-push')) {
      buildCommand += buildAndPushImage()
    }
    if (params.ENABLED_STAGES.contains('build-config-push')) {
      buildCommand += buildAndPushConfiguredImage()
    }

    if (env.OS_TYPE == 'linux') {
      def buildLogFile = "/tmp/docker_build_${env.BUILD_ID}.log"
      def exitCode = sh(script: """#!/bin/bash
set -eo pipefail
{
${buildCommand}
} 2>&1 | tee ${buildLogFile}""", returnStatus: true)
      if (exitCode != 0) {
        try {
          def capturedLog = sh(script: "tail -150 ${buildLogFile} 2>/dev/null || echo 'Build log not available'", returnStdout: true).trim()
          env.FAILED_STACK_TRACE = "Docker Build Output (last 150 lines):\n${capturedLog}"
        } catch (Exception ignored) {}
        sh "rm -f ${buildLogFile} || true"
        error("Docker build failed with exit code: ${exitCode}")
      }
      sh "rm -f ${buildLogFile} || true"
    } else {
      bat buildCommand
    }

    def imageTag
    if (params.ENABLED_STAGES.contains('build-config-push')) {
      // env.IMAGETAG đã được set bởi buildAndPushConfiguredImage() với đúng timestamp
      imageTag = env.IMAGETAG
    } else {
      def imageBasePath = "${REGISTRY_URL}/"
      if (PATH_NAME?.trim()) {
        imageBasePath += "${PATH_NAME}/"
      }
      imageBasePath += "${REPOSITORY_NAME}/${params.PROJECT_NAME}"
      imageTag = "${imageBasePath}:${params.ENVIRONMENT}-${env.BUILD_ID}"
      env.IMAGETAG = imageTag
    }

    currentBuild.description = "Image Tag: ${imageTag}"
    def timeStamp = new Date().format("HH:mm:ss'-'dd-MM-yyyy")

    env.TIMESTAMP = timeStamp

    echo "The image release is: ${imageTag}"
    echo "The image build at: ${timeStamp} (GMT+7)"
    echo "Set image release success"
  } catch (Exception e) {
    captureStageError('Build and push image', e)
  }
}

// Stage: Clean old docker images
def runCleanOldDockerImages() {
  currentBuild.displayName = "${params.PATH_NAME} - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.LOCATION} - ${STAGE_NAME}"
  try {
    echo "Check docker image, nếu nhiều hơn 2 thì xoá image cũ."
    def imagesOutput = getDockerImages(env.OS_TYPE)
    def imagesList = imagesOutput.split('\n')
    cleanOldImages(imagesList, 2, env.OS_TYPE)
  } catch (Exception e) {
    captureStageError('Clean old docker images', e)
  }
}

// Stage: Trigger CD client
def runTriggerCDClient() {
  currentBuild.displayName = "${params.PATH_NAME} - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.LOCATION} - ${STAGE_NAME}"
  try {
    def imageTag = env.IMAGETAG
    def timeStamp = env.TIMESTAMP
    echo "The image tag is: ${imageTag}"
    echo "The image build at: ${timeStamp} (GMT+7)"
    echo "Commit hash is: ${env.COMMIT_NAME}"
    echo "Commit message is: ${env.COMMIT_MESSAGE}"

    if (ACTION_TYPE == 'TRIGGER_CD_ONLY' && (imageTag == null || imageTag.trim().isEmpty())) {
      error("Lỗi: Bạn đã chọn 'TRIGGER_CD_ONLY' nhưng không cung cấp IMAGETAG.")
    }

    def encodedImageTag = URLEncoder.encode(imageTag, "UTF-8")
    def triggerUrl = "${params.JENKINS_CLIENT_URL}/buildWithParameters?IMAGETAG=${encodedImageTag}&TIMESTAMP=${timeStamp}&COMMIT_NAME=${env.COMMIT_NAME}&COMMIT_MESSAGE=${URLEncoder.encode(env.COMMIT_MESSAGE,'UTF-8')}&PROJECT_NAME=${params.PROJECT_NAME}&ENVIRONMENT=${params.ENVIRONMENT}&PATH_NAME=${params.PATH_NAME}&VAULT_PATH=${params.VAULT_PATH}&TEAMS_WEBHOOK_URL=${params.TEAMS_WEBHOOK_URL}&CLIENT_LOCATION=${params.CLIENT_LOCATION}&CLIENT_ENV_ACTION=client-trigger&CLIENT_ENABLED_STAGES=${URLEncoder.encode(params.CLIENT_ENABLED_STAGES, 'UTF-8')}&CLIENT_SECRET_VAULT=${URLEncoder.encode(params.CLIENT_SECRET_VAULT, 'UTF-8')}&CLIENT_SECRET_NAME=${URLEncoder.encode(params.CLIENT_SECRET_NAME, 'UTF-8')}&CLIENT_LOCATION_VAULT=${URLEncoder.encode(params.CLIENT_LOCATION_VAULT, 'UTF-8')}&DC_ENABLED_STAGES=${URLEncoder.encode(params.DC_ENABLED_STAGES, 'UTF-8')}&DC_KUBE_CONFIG_FILE=${params.DC_KUBE_CONFIG_FILE}&DC_VAULT_ADDR=${params.DC_VAULT_ADDR}&DC_VAULT_TOKEN=${params.DC_VAULT_TOKEN}&DC_JENKINS_URL=${params.DC_JENKINS_URL}&DC_JENKINS_USER=${params.DC_JENKINS_USER}&DC_JENKINS_TOKEN=${params.DC_JENKINS_TOKEN}&DR_ENABLED_STAGES=${URLEncoder.encode(params.DR_ENABLED_STAGES, 'UTF-8')}&DR_KUBE_CONFIG_FILE=${params.DR_KUBE_CONFIG_FILE}&DR_VAULT_ADDR=${params.DR_VAULT_ADDR}&DR_VAULT_TOKEN=${params.DR_VAULT_TOKEN}&DR_JENKINS_URL=${params.DR_JENKINS_URL}&DR_JENKINS_USER=${params.DR_JENKINS_USER}&DR_JENKINS_TOKEN=${params.DR_JENKINS_TOKEN}"
    
    withCredentials([
      string(credentialsId: "${params.JENKINS_CLIENT_USER}", variable: 'JENKINS_CLIENT_USER'),
      string(credentialsId: "${params.JENKINS_CLIENT_TOKEN}", variable: 'JENKINS_CLIENT_TOKEN')
    ]) {
      def triggerCommand = """
          curl -k -sSf -u  ${JENKINS_CLIENT_USER}:${JENKINS_CLIENT_TOKEN} -I -X POST "${triggerUrl}"
          echo "Trigger CD client success"
      """
      if (env.OS_TYPE == 'linux') {
        sh triggerCommand
      } else {
        bat triggerCommand
      }
    }
  } catch (Exception e) {
    captureStageError('Trigger CD client', e)
  }
}

// Stage: Apply Secrets
def runApplySecrets() {
  try {
    def stageType = params.CLIENT_ENABLED_STAGES.contains('deploy-dc') ? 'DC' : 'DR'
    currentBuild.displayName = "${stageType} - ${params.PATH_NAME} - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.CLIENT_LOCATION} - Apply Secrets"
    applySecrets(stageType)
  } catch (Exception e) {
    captureStageError('Apply Secrets', e)
  }
}

// Stage: Unit Test before deploy new version
def runUnitTest() {
  timeout(time: 60, unit: 'MINUTES') {
    try {
      def stageType = params.CLIENT_ENABLED_STAGES.contains('unit-test-dc') ? 'DC' : 'DR'
      currentBuild.displayName = "${stageType} ${params.ERP_APP_NAME} - ${params.PATH_NAME} - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.CLIENT_LOCATION} - Unit Test Before Deploy"
      deployForUnitTest(stageType)
      def podName = getPodName()
      def result = runUnitTestsOnPod(podName)
      sendLogToTeams(result.output, stageType)
      if (result.status != 0) {
        def errorMessage = "Unit test failed with error: ${result.output}"
        currentBuild.description = errorMessage
        error(errorMessage)
      }
    } catch (Exception e) {
      captureStageError('Unit Test before deploy new version', e)
    } finally {
      scaleDownUnitTestDeployment()
    }
  }
}

// Stage: Deploy to Cluster
def runDeployToCluster() {
  timeout(time: 60, unit: 'MINUTES') {
    try {
      def stageType = params.CLIENT_ENABLED_STAGES.contains('deploy-dc') ? 'DC' :
                      params.CLIENT_ENABLED_STAGES.contains('deploy-dr') ? 'DR' : 'ERP'

      currentBuild.displayName = "${stageType} ${params.ERP_APP_NAME} - ${params.PATH_NAME} - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.CLIENT_LOCATION} - Deploy to Cluster"
      
      if (stageType == 'ERP') {
        deployToERP(stageType)
      } else {
        deployToCluster(stageType)
      }
    } catch (Exception e) {
      captureStageError('Deploy to Cluster', e)
    }
  }
}

// Stage: Apply configure to DC and DR
def runApplyConfigure() {
  currentBuild.displayName = "${params.PATH_NAME} - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.CLIENT_LOCATION} - ${STAGE_NAME}"
  def stageType
  try {
    stageType = params.CLIENT_ENABLED_STAGES.contains('configure-dc') ? 'DC' : 'DR'
    def kubeConfigFile = stageType == 'DC' ? params.DC_KUBE_CONFIG_FILE : params.DR_KUBE_CONFIG_FILE
    withCredentials([file(credentialsId: kubeConfigFile, variable: 'KUBE_CONFIG_FILE')]) {
      def config = readFile file: KUBE_CONFIG_FILE // FIX
      writeFile file: 'kube-config', text: config
      def dirPath = "${params.PROJECT_NAME}-${params.ENVIRONMENT}"
      applyKubernetesConfig(params, dirPath, stageType)
      def result = deployToKubernetes(params)
      echo "${stageType} Apply configure result: ${result}"
      if (result != 0) {
        error("${stageType} Apply configure failed. Stopping the pipeline.")
      }
      checkPodStatus(params, stageType)
      def logFilePath = "${dirPath}/output.log"
      getPodLogs(params, logFilePath)
    }
  } catch (Exception e) {
    captureStageError("${stageType} Apply configure to DC and DR", e)
  } finally {
    if (stageType) {
        def kubeConfigFile = stageType == 'DC' ? params.DC_KUBE_CONFIG_FILE : params.DR_KUBE_CONFIG_FILE
        if (kubeConfigFile) {
            withCredentials([file(credentialsId: kubeConfigFile, variable: 'KUBE_CONFIG_FILE_CLEANUP')]) {
                writeFile file: 'kube-config', text: readFile(file: KUBE_CONFIG_FILE_CLEANUP) // FIX
                cleanUpPod(params, stageType)
            }
        }
    }
  }
}

// Stage: Trigger DC and DR deploy
def runTriggerDCandDRDeploy() {
  currentBuild.displayName = "${params.PATH_NAME} - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.CLIENT_LOCATION} - ${STAGE_NAME}"

  def triggerUrls = []
  if (params.CLIENT_ENABLED_STAGES.contains('trigger-dc')) {
    def dcTriggerUrl = "${params.DC_JENKINS_URL}/buildWithParameters?IMAGETAG=${java.net.URLEncoder.encode(params.IMAGETAG, 'UTF-8')}&TIMESTAMP=${params.TIMESTAMP}&COMMIT_NAME=${env.COMMIT_NAME}&COMMIT_MESSAGE=${URLEncoder.encode(env.COMMIT_MESSAGE, 'UTF-8')}&PROJECT_NAME=${params.PROJECT_NAME}&ENVIRONMENT=${params.ENVIRONMENT}&PATH_NAME=${params.PATH_NAME}&VAULT_PATH=${params.VAULT_PATH}&TEAMS_WEBHOOK_URL=${params.TEAMS_WEBHOOK_URL}&CLIENT_LOCATION=${params.CLIENT_LOCATION}&CLIENT_ENV_ACTION=client-deploy&CLIENT_ENABLED_STAGES=${URLEncoder.encode(params.DC_ENABLED_STAGES, 'UTF-8')}&CLIENT_SECRET_VAULT=${URLEncoder.encode(params.CLIENT_SECRET_VAULT, 'UTF-8')}&CLIENT_SECRET_NAME=${URLEncoder.encode(params.CLIENT_SECRET_NAME, 'UTF-8')}&CLIENT_LOCATION_VAULT=${URLEncoder.encode(params.CLIENT_LOCATION_VAULT, 'UTF-8')}&DC_ENABLED_STAGES=${URLEncoder.encode(params.DC_ENABLED_STAGES, 'UTF-8')}&DC_KUBE_CONFIG_FILE=${params.DC_KUBE_CONFIG_FILE}&DC_VAULT_ADDR=${params.DC_VAULT_ADDR}&DC_VAULT_TOKEN=${params.DC_VAULT_TOKEN}"
    triggerUrls.add([url: dcTriggerUrl, user: params.DC_JENKINS_USER, token: params.DC_JENKINS_TOKEN])
  }
  if (params.CLIENT_ENABLED_STAGES.contains('trigger-dr')) {
    def drTriggerUrl = "${params.DR_JENKINS_URL}/buildWithParameters?IMAGETAG=${java.net.URLEncoder.encode(params.IMAGETAG, 'UTF-8')}&TIMESTAMP=${params.TIMESTAMP}&COMMIT_NAME=${env.COMMIT_NAME}&COMMIT_MESSAGE=${URLEncoder.encode(env.COMMIT_MESSAGE, 'UTF-8')}&PROJECT_NAME=${params.PROJECT_NAME}&ENVIRONMENT=${params.ENVIRONMENT}&PATH_NAME=${params.PATH_NAME}&VAULT_PATH=${params.VAULT_PATH}&TEAMS_WEBHOOK_URL=${params.TEAMS_WEBHOOK_URL}&CLIENT_LOCATION=${params.CLIENT_LOCATION}&CLIENT_ENV_ACTION=client-deploy&CLIENT_ENABLED_STAGES=${URLEncoder.encode(params.DR_ENABLED_STAGES, 'UTF-8')}&CLIENT_SECRET_VAULT=${URLEncoder.encode(params.CLIENT_SECRET_VAULT, 'UTF-8')}&CLIENT_SECRET_NAME=${URLEncoder.encode(params.CLIENT_SECRET_NAME, 'UTF-8')}&CLIENT_LOCATION_VAULT=${URLEncoder.encode(params.CLIENT_LOCATION_VAULT, 'UTF-8')}&DR_ENABLED_STAGES=${URLEncoder.encode(params.DR_ENABLED_STAGES, 'UTF-8')}&DR_KUBE_CONFIG_FILE=${params.DR_KUBE_CONFIG_FILE}&DR_VAULT_ADDR=${params.DR_VAULT_ADDR}&DR_VAULT_TOKEN=${params.DR_VAULT_TOKEN}"
    triggerUrls.add([url: drTriggerUrl, user: params.DR_JENKINS_USER, token: params.DR_JENKINS_TOKEN])
  }

  for (trigger in triggerUrls) {
    try {
      echo "Triggering URL: ${trigger.url}"
      withCredentials([
        string(credentialsId: trigger.user, variable: 'JENKINS_USER'),
        string(credentialsId: trigger.token, variable: 'JENKINS_TOKEN')
      ]) {
        def triggerCommand = ""
        if (env.OS_TYPE == 'linux') {
          triggerCommand = """
              curl -k -sSf -u ${JENKINS_USER}:${JENKINS_TOKEN} -I -X POST "${trigger.url}"
              echo "Trigger deploy success for URL: ${trigger.url}"
          """
          sh(script: triggerCommand, returnStatus: true)
        } else {
          def escapedTriggerUrl = trigger.url.replace('%', '%%')
          triggerCommand = """
              curl -k -sSf -u ${JENKINS_USER}:${JENKINS_TOKEN} -I -X POST "${escapedTriggerUrl}"
              echo "Trigger deploy success for URL: ${escapedTriggerUrl}"
          """
          bat(script: triggerCommand, returnStatus: true)
        }
      }
    } catch (Exception e) {
      captureStageError('Trigger DC and DR deploy', e)
    }
  }
}

// Stage: Replace vault pipeline
def runReplaceVaultPipeline() {
  try {
    currentBuild.displayName = "${params.PATH_NAME} - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.CLIENT_LOCATION} - Replace vault pipeline"
    sh replaceVaultPipeline()
  } catch (Exception e) {
    captureStageError('Replace vault pipeline', e)
  }
}

// Stage: Work Flow Process
def runWorkFlowProcess() {
  try {
    currentBuild.displayName = "${params.PATH_NAME} - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.CLIENT_LOCATION} - Work Flow Process"
    sh workFlowProcess()
  } catch (Exception e) {
    captureStageError('Work Flow Process', e)
  }
}

// Post-Success Action
def runPostSuccess() {
  def successMessage = "${params.ERP_APP_NAME} - ${currentBuild.displayName} --- succeeded!"
  office365ConnectorSend message: successMessage, status: 'SUCCESS', webhookUrl: "${env.TEAMS_WEBHOOK_URL}"
}

// Post-Failure Action
def runPostFailure() {
  def failedStage = env.FAILED_STAGE_NAME ?: 'Unknown'
  def errorMsg = env.FAILED_ERROR_MESSAGE ?: currentBuild.description ?: 'Unknown error'
  def stackTrace = env.FAILED_STACK_TRACE ?: ''
  def consoleLog = env.FAILED_CONSOLE_LOG ?: ''

  // Truncate nếu quá dài (Teams webhook giới hạn ~28KB)
  def maxLen = 8000
  if (stackTrace.length() > maxLen) {
    stackTrace = stackTrace.substring(0, maxLen) + '\n... (truncated)'
  }
  if (consoleLog.length() > maxLen) {
    consoleLog = consoleLog.substring(consoleLog.length() - maxLen) + '\n... (showing last portion)'
  }

  // Escape ký tự đặc biệt cho JSON
  errorMsg = errorMsg.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')
  stackTrace = stackTrace.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')
  consoleLog = consoleLog.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')

  // Gửi chi tiết lỗi qua httpRequest (MessageCard)
  def payload = [
    "@type"      : "MessageCard",
    "@context"   : "http://schema.org/extensions",
    "summary"    : "Pipeline Failed: ${failedStage}",
    "themeColor" : "FF0000",
    "title"      : "❌ PIPELINE FAILED: ${currentBuild.displayName}",
    "sections"   : [
      [
        "activityTitle"    : "Failed Stage: ${failedStage}",
        "activitySubtitle" : "Project: ${params.PROJECT_NAME} | Env: ${params.ENVIRONMENT} | Location: ${params.LOCATION} ${params.CLIENT_LOCATION}",
        "facts"            : [
          ["name": "Error", "value": errorMsg],
          ["name": "Build URL", "value": "${env.BUILD_URL}"],
          ["name": "Timestamp", "value": new Date().format("HH:mm:ss dd-MM-yyyy")]
        ]
      ],
      [
        "activityTitle" : "Stack Trace",
        "text"          : "```\n${stackTrace}\n```"
      ],
      [
        "activityTitle" : "Console Log (last lines)",
        "text"          : "```\n${consoleLog}\n```"
      ]
    ]
  ]

  try {
    httpRequest(
      httpMode: 'POST',
      contentType: 'APPLICATION_JSON',
      requestBody: JsonOutput.toJson(payload),
      url: "${env.TEAMS_WEBHOOK_URL}",
      ignoreSslErrors: true
    )
  } catch (Exception webhookEx) {
    echo "WARNING: Failed to send detailed error to webhook: ${webhookEx.getMessage()}"
  }
}

// Helper: Capture full error details for a stage
def captureStageError(String stageName, Exception e) {
  env.FAILED_STAGE_NAME = stageName
  env.FAILED_ERROR_MESSAGE = e.getMessage() ?: 'Unknown error'

  // Chỉ set stack trace từ Java exception nếu chưa được set bởi caller
  // (ví dụ: docker build output đã được capture trước đó)
  if (!env.FAILED_STACK_TRACE) {
    def sw = new java.io.StringWriter()
    e.printStackTrace(new java.io.PrintWriter(sw))
    env.FAILED_STACK_TRACE = sw.toString()
  }

  env.FAILED_CONSOLE_LOG = "See full console log at: ${env.BUILD_URL}console"
  currentBuild.description = "${stageName} failed: ${e.getMessage()}"
  throw e
}


// --------------------------------------------------------------------------------------------
// ---------------------------- CÁC HÀM GỐC CỦA BẠN (GIỮ NGUYÊN) -------------------------------
// --------------------------------------------------------------------------------------------

// --------------------------- Get release version information --------------------------------
def detectOSType() {
  if (isUnix()) {
    env.OS_TYPE = 'linux'
  } else {
    env.OS_TYPE = 'windows'
  }
  echo "The current Jenkins used OS: ${env.OS_TYPE}"
}

def displayCompanyInfo() {
  echo "-------------------------- Company information --------------------------"
  echo "-------------------------------------------------------------------------"
  echo "Company project will deploy: ${params.PROJECT_NAME}"
  echo "Company environment will deploy: ${params.ENVIRONMENT}"
  echo "Company modules will be deploy: ${params.MODULE_DEPLOY}"
  echo "Company registry name: ${params.REGISTRY_URL}"
  echo "Company branch code: ${params.BRANCH_CODE}"
  echo "Company location: ${params.LOCATION}"
  echo "Company path will deploy: ${params.PATH_NAME}"
  echo "Company path of vault: ${params.VAULT_PATH}"
  echo "Company key of vault: ${params.COMPANY_SECRET_VAULT}"
  echo "Company location vault: ${params.COMPANY_LOCATION_VAULT}"
  echo "Company source code will clone: ${params.SOURCE_CODE_PATH}"
  echo "Company stage will be apply: ${params.ENABLED_STAGES}"
  echo "-------------------------------------------------------------------------"
}

def displayClientInfo() {
  echo "-------------------------- Client information ---------------------------"
  // ... (giữ nguyên)
  echo "Client Path of vault: ${params.VAULT_PATH}"
  echo "Client key vault: ${params.CLIENT_SECRET_VAULT}"
  echo "Client location vault: ${params.CLIENT_LOCATION_VAULT}"
  echo "Client secret name: ${params.CLIENT_SECRET_NAME}"
  echo "Client location: ${params.CLIENT_LOCATION}"
  echo "Client Stage will be apply: ${params.CLIENT_ENABLED_STAGES}"
  echo "Client DC Stage will be apply: ${params.DC_ENABLED_STAGES}"
  echo "Client DR Stage will be apply: ${params.DR_ENABLED_STAGES}"
  echo "Client action environment used: ${params.CLIENT_ENV_ACTION}"
  echo "-------------------------------------------------------------------------"
}
// --------------------------------------------------------------------------------------------

// ---------------------------------- Checkout source code ------------------------------------
def verifyGitlabToken() {
  if (params.GITLAB_ACCESS_TOKEN == '') {
    error "GITLAB_ACCESS_TOKEN must be provided."
  }
}

def checkoutSourceCode() {
  withCredentials([string(credentialsId: "${params.GITLAB_ACCESS_TOKEN}", variable: 'GITLAB_ACCESS_TOKEN')]) {
    checkout([
      $class: 'GitSCM',
      branches: [[name: "$pipelineBranchCode"]],
      doGenerateSubmoduleConfigurations: false,
      extensions: [
        [$class: 'RelativeTargetDirectory', relativeTargetDir: "${params.PROJECT_NAME}-${params.ENVIRONMENT}"]
      ],
      submoduleCfg: [],
      userRemoteConfigs: [
        [
          url: "https://oauth2:${GITLAB_ACCESS_TOKEN}@gitlab.com/${SOURCE_CODE_PATH}.git"
        ]
      ]
    ])
  }
}

def retrieveCommitDetails() {
  def commitHash = sh(script: "git -C ${params.PROJECT_NAME}-${params.ENVIRONMENT} rev-parse --short HEAD", returnStdout: true).trim()
  def commitMessage = sh(script: "git -C ${params.PROJECT_NAME}-${params.ENVIRONMENT} log -1 --pretty=%B", returnStdout: true).trim()
  env.COMMIT_NAME = commitHash
  env.COMMIT_MESSAGE = commitMessage
  echo "Commit hash is: ${env.COMMIT_NAME}"
  echo "Commit message is: ${env.COMMIT_MESSAGE}"
}
// ---------------------------------------------------------------------------------------------


// -----------------------------------  Grunt source -------------------------------------------
def setupGruntEnvironment() {
  def gruntSetupCommand = """
    cd ${params.PROJECT_NAME}-${params.ENVIRONMENT}/
    node -v
    for file in package.json package-lock.json; do [ -e "\$file" ] && mv "\$file" "\${file}.org"; done
    npm install -g grunt-cli
    npm install sails-hook-grunt grunt grunt-md5 terser grunt-sync grunt-contrib-watch grunt-contrib-uglify grunt-contrib-jst include-all grunt-contrib-less grunt-sails-linker grunt-contrib-clean grunt-contrib-coffee grunt-contrib-concat grunt-contrib-cssmin grunt-contrib-copy javascript-obfuscator grunt-contrib-obfuscator load-grunt-tasks --save-dev
  """
  return gruntSetupCommand
}

def runGruntBackend() {
  return """
    grunt
    echo "Grunt backend success"
  """
}

def runGruntFrontend() {
  return """
    grunt uglify:ts
    node removeControllers.js
    echo "Grunt frontend success"
  """
}

def cleanup() {
  return """
    echo "--------------- Cleanup -----------------"
    for item in dist node_modules Gruntfile.js .git .gitignore .gitlab-ci.yml script.sh .tmp removeControllers.js; do
      [ -e "\$item" ] && rm -rf "\$item"
    done
    for file in package.json.org package-lock.json.org; do [ -e "\$file" ] && mv "\$file" "\${file%.org}"; done
    echo "--------- Cleaning success --------------"
  """
}
// -------------------------------------------------------------------------

// ------------------------------ Helper Naming Context ------------------------------
def getNamingContext() {
    def prefix = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-" : ""
    return [
        prefix      : prefix,
        namespace   : "${prefix}${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns",
        deployment  : "${prefix}${params.PROJECT_NAME}-${params.ENVIRONMENT}-deployment",
        unitTestDep : "${prefix}${params.PROJECT_NAME}-${params.ENVIRONMENT}-unit-test-deployment",
        container   : "${prefix}${params.PROJECT_NAME}-${params.ENVIRONMENT}-container",
        appLabel    : "${prefix}${params.PROJECT_NAME}-${params.ENVIRONMENT}-unit-test-app",
    ]
}

// ------------------------------ Build and push image ----------------------------------------
def prepareDockerConfig() {
  withCredentials([file(credentialsId: "${params.REGISTRY_AUTH}", variable: 'REGISTRY_AUTH')]) {
    sh """
      cat ${REGISTRY_AUTH} > ~/.docker/config.json
      cd ${params.PROJECT_NAME}-${params.ENVIRONMENT}/
      echo "Dockerfile" > .dockerignore
    """
  }
}
def buildAndPushImage() {
  def imagePath = "${REGISTRY_URL}/"
  if (PATH_NAME?.trim()) {
    imagePath += "${PATH_NAME}/"
  }
  imagePath += "${REPOSITORY_NAME}/${params.PROJECT_NAME}:${params.ENVIRONMENT}-${env.BUILD_ID}"

  def buildCommand = """
    echo "Commit hash is: ${env.COMMIT_NAME}"
    echo "Commit message is: ${env.COMMIT_MESSAGE}"
    cd ${params.PROJECT_NAME}-${params.ENVIRONMENT}/
    docker build -t ${imagePath} .
    docker push ${imagePath}
    echo "Build and push image success"
  """
  return buildCommand
}

def buildAndPushConfiguredImage() {
  // Tạo timestamp với định dạng mong muốn.
  def timestamp = new Date().format('HHmmss-ddMMyyyy')
  
  def imagePath = "${REGISTRY_URL}/"
  if (PATH_NAME?.trim()) {
    imagePath += "${PATH_NAME}/"
  }
  
  // Thêm biến timestamp vào cuối tag name
  imagePath += "${REPOSITORY_NAME}/${params.PROJECT_NAME}:configure-${params.ENVIRONMENT}-${env.COMMIT_MESSAGE}-${timestamp}"

  // Lưu lại để runBuildAndPushImage() dùng đúng tag (có timestamp)
  env.IMAGETAG = imagePath

  def buildCommand = """
    echo "Commit hash is: ${env.COMMIT_NAME}"
    echo "Commit message is: ${env.COMMIT_MESSAGE}"
    cd ${params.PROJECT_NAME}-${params.ENVIRONMENT}/
    sed -i 's/RELEASE/${env.COMMIT_MESSAGE}/g' Dockerfile
    docker build -t ${imagePath} .
    docker push ${imagePath}
    echo "Build and push configure image success"
  """
  return buildCommand
}
// --------------------------------------------------------------------------------------------

// ---------------------------- Clean old image ----------------------------
def getDockerImages(osType) {
  def imagePrefix = "${REGISTRY_URL}/"
  if (PATH_NAME?.trim()) {
    imagePrefix += "${PATH_NAME}/"
  }
  imagePrefix += "${REPOSITORY_NAME}/${params.PROJECT_NAME}"

  if (osType == 'linux') {
    return sh(
      script: "docker images --format '{{.Repository}} {{.Tag}} {{.ID}} {{.CreatedAt}}' | grep '${imagePrefix}' | sort -k4",
      returnStdout: true
    ).trim()
  } else {
    def winImagePrefix = imagePrefix.replaceAll('/', '\\\\')
    return bat(
      script: "docker images --format \"{{.Repository}} {{.Tag}} {{.ID}} {{.CreatedAt}}\" | findstr \"${winImagePrefix}\" | sort",
      returnStdout: true
    ).trim()
  }
}

def cleanOldImages(imagesList, keep, osType) {
  if (imagesList.size() > keep) {
    def imagesToDelete = imagesList.take(imagesList.size() - keep).collect {
      it.split()[2]
    }
    imagesToDelete.each {
      imageId ->
        if (osType == 'linux') {
          sh "docker rmi $imageId -f"
        } else {
          bat "docker rmi $imageId -f"
        }
    }
  } else {
    echo "Không có gì để xoá, chỉ có ${imagesList.size()} image."
  }
}

// --------------------------------------- Apply configure to system --------------------------------------- 
def getConfigurePodName() {
    def prefix = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-" : ""
    return "${prefix}${params.PROJECT_NAME}-${params.ENVIRONMENT}-configure"
}

def getLogFileName() {
    def date = new Date().format('yyyy-MM-dd-HH-mm', TimeZone.getTimeZone('GMT+7'))
    def prefix = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-" : ""
    return "output-cicd-configure-${prefix}${date}.log"
}

def applyKubernetesConfig(params, filePath, stageType) {
  def podFilePath = "${filePath}/pod-configure.yaml"
  
  // 1. Tính toán tên Pod Dynamic
  def podName = getConfigurePodName() 
  // 2. Tính toán Namespace Dynamic
  def namespace = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns" : "${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns"

  if (fileExists(podFilePath)) {
    def podconfigContent = readFile(podFilePath)
    
    // 3. Thay thế IMAGE
    podconfigContent = podconfigContent.replaceAll('IMAGE', "${params.IMAGETAG}")
    // 4. Thay thế POD NAME (cho cả metadata.name, labels, và container name)
    if (podconfigContent.contains('POD_NAME_PLACEHOLDER')) {
        podconfigContent = podconfigContent.replaceAll('POD_NAME_PLACEHOLDER', podName)
    } else {
        // Fallback: Nếu trên Vault vẫn để tên cũ 'podconfigure'
        podconfigContent = podconfigContent.replaceAll('podconfigure', podName)
    }
    // 5. Thay thế NAMESPACE
    if (podconfigContent.contains('NAMESPACE_PLACEHOLDER')) {
        podconfigContent = podconfigContent.replaceAll('NAMESPACE_PLACEHOLDER', namespace)
    } else {
        // Tốt nhất là bạn nên sửa file Vault thành NAMESPACE_PLACEHOLDER
    }
    
    def outputFilePath = "${filePath}/podconfig.yaml"
    writeFile(file: outputFilePath, text: podconfigContent)
    echo "File podconfig.yaml generated. Pod: ${podName} | Namespace: ${namespace}"
  } else {
    error "The file ${podFilePath} does not exist. Please check the path and try again."
  }
}

def deployToKubernetes(params) {
    def namespace = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns" : "${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns"
    def projectNameEnv = "${params.PROJECT_NAME}-${params.ENVIRONMENT}"
    
    // Kiểm tra OS
    def isServerUnix = isUnix()
    echo "DEBUG: Detected isUnix() = ${isServerUnix}"

    if (isServerUnix) {
        def podConfigPath = "${projectNameEnv}/podconfig.yaml"
        def configureScript = "${projectNameEnv}/configure.sh"
        
        echo "DEBUG: Running on Linux path"
        def linuxCommand = """
            echo "Release version: ${params.IMAGETAG}"
            echo "Apply configure-secret"
            kubectl --kubeconfig kube-config create secret generic configure-secret --from-file=${configureScript} -n ${namespace} --dry-run=client -o yaml | kubectl --kubeconfig kube-config apply -f -
            
            if [ -f "${podConfigPath}" ]; then
                echo "Applying ${podConfigPath}..."
                kubectl --kubeconfig kube-config --insecure-skip-tls-verify -n ${namespace} apply -f ${podConfigPath}
            else
                echo "ERROR: ${podConfigPath} not found!"
                exit 1
            fi
        """
        return sh(script: linuxCommand, returnStatus: true)
    } else {
        // Windows: Chuyển đổi đường dẫn sang dấu \ để an toàn cho CMD
        def podConfigPathWin = "${projectNameEnv}\\podconfig.yaml"
        def configureScriptWin = "${projectNameEnv}\\configure.sh"
        
        echo "DEBUG: Running on Windows path"
        def winCommand = """
            echo "Release version: ${params.IMAGETAG}"
            echo "Apply configure-secret"
            kubectl --kubeconfig kube-config create secret generic configure-secret --from-file=${configureScriptWin} -n ${namespace} --dry-run=client -o yaml | kubectl --kubeconfig kube-config apply -f -
            
            if exist "${podConfigPathWin}" (
                echo "Applying ${podConfigPathWin}..."
                @rem Xóa bỏ flag --ignore-not-found vì kubectl apply không hỗ trợ
                kubectl --kubeconfig kube-config --insecure-skip-tls-verify -n ${namespace} apply -f "${podConfigPathWin}"
            ) else (
                echo "ERROR: ${podConfigPathWin} not found!"
                exit 1
            )
        """
        return bat(script: winCommand, returnStatus: true)
    }
}


def checkPodStatus(params, stageType) {
  def namespace = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns" : "${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns"
  def podName = getConfigurePodName()
  def podStatus = ''
  
  echo "Checking status for pod: ${podName} in namespace: ${namespace}. Max wait time: 10 minutes."

  for (int i = 0; i < 60; i++) {
    def statusCommand = "kubectl --kubeconfig kube-config get pod ${podName} -n ${namespace} -o jsonpath=\"{.status.phase}\""
    
    // Sử dụng isUnix() thay vì env.OS_TYPE
    if (isUnix()) {
        podStatus = sh(script: statusCommand, returnStdout: true).trim()
    } else {
        podStatus = bat(script: statusCommand, returnStdout: true).trim()
    }
    
    // Xử lý chuỗi trả về từ Windows (thường kèm theo lệnh thực thi)
    podStatus = podStatus.split('\n')[-1].trim().replaceAll("[^a-zA-Z]", "")
    echo "Current Pod status: ${podStatus}"

    if (podStatus == 'Succeeded') {
      break
    } else if (podStatus == 'Failed') {
      error "Pod ${podName} failed to complete successfully"
    }
    sleep(10)
  }

  if (podStatus != 'Succeeded') {
    error "Pod ${podName} did not complete in time (10 minutes timeout)."
  }
}

def getPodLogs(params, logFilePath) {
  def namespace = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns" : "${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns"
  def podName = getConfigurePodName()
  def dynamicLogFileName = getLogFileName()

  def logCommand = "kubectl --kubeconfig kube-config logs pod/${podName} -n ${namespace} > ${dynamicLogFileName}"
  if (isUnix()) { sh logCommand } else { bat logCommand }

  def outputLog = readFile(dynamicLogFileName)

  // ---- Parse tất cả các response block trong log ----
  def failedImports = []
  def successCount = 0
  def totalCount = 0

  def blocks = outputLog.split('----------------------')
  for (block in blocks) {
    def blockTrimmed = block.trim()
    if (!blockTrimmed) continue

    def fileNameMatch = (blockTrimmed =~ /(?i)Importing\s+(\S+)/)
    def fileName = fileNameMatch ? fileNameMatch[0][1] : 'Unknown file'

    def errorCodeMatch = (blockTrimmed =~ /(?i)"errorCode"\s*:\s*(\d+)/)
    if (!errorCodeMatch) continue

    totalCount++
    def errorCode = errorCodeMatch[0][1] as Integer

    if (errorCode != 0) {
      def errorMsgMatch = (blockTrimmed =~ /(?i)"errorMsg"\s*:\s*"([^"]*)"/)
      def errorMsg = errorMsgMatch ? errorMsgMatch[0][1] : 'Unknown error'
      failedImports.add([file: fileName, errorCode: errorCode, errorMsg: errorMsg])
    } else {
      successCount++
    }
  }

  echo "Configure log validation: ${successCount} success, ${failedImports.size()} failed, ${totalCount} total responses."
  echo "Log saved to: ${dynamicLogFileName}"

  // ---- Luôn gửi toàn bộ nội dung file log sang Teams webhook ----
  sendConfigureLogToWebhook(outputLog, successCount, failedImports.size(), totalCount, dynamicLogFileName)

  if (failedImports.isEmpty() && totalCount > 0) {
    echo "All ${totalCount} configure imports completed successfully."
  } else if (failedImports.size() > 0) {
    def errorDetails = failedImports.collect { item ->
      "  - File: ${item.file} | errorCode: ${item.errorCode} | errorMsg: ${item.errorMsg}"
    }.join('\n')
    error "Configure import failed! ${failedImports.size()}/${totalCount} files had errors:\n${errorDetails}"
  } else {
    error "Logic Error: No valid response blocks found in log file ${dynamicLogFileName}."
  }
}

// Helper: Gửi toàn bộ nội dung file log sang Teams webhook (cả success lẫn failed)
def sendConfigureLogToWebhook(logContent, successCount, failedCount, totalCount, logFileName) {
  def isSuccess = (failedCount == 0 && totalCount > 0)
  def themeColor = isSuccess ? '00C851' : 'FF6600'
  def statusIcon = isSuccess ? '✅' : '⚠️'
  def statusText = isSuccess ? "SUCCESS" : "FAILED"

  // Truncate nếu quá dài (~18KB để an toàn với Teams)
  def maxLen = 18000
  def truncated = false
  if (logContent.length() > maxLen) {
    logContent = logContent.substring(0, maxLen)
    truncated = true
  }

  def payload = [
    "@type"     : "MessageCard",
    "@context"  : "http://schema.org/extensions",
    "summary"   : "Configure Log: ${statusText}",
    "themeColor": themeColor,
    "title"     : "${statusIcon} CONFIGURE LOG [${statusText}]: ${currentBuild.displayName}",
    "sections"  : [
      [
        "activityTitle"    : "Result: ${successCount} success / ${failedCount} failed / ${totalCount} total",
        "activitySubtitle" : "Project: ${params.PROJECT_NAME} | Env: ${params.ENVIRONMENT} | File: ${logFileName}",
        "facts"            : [
          ["name": "Build URL", "value": "${env.BUILD_URL}"],
          ["name": "Log File",  "value": logFileName]
        ]
      ],
      [
        "activityTitle": "Log Content${truncated ? ' (truncated to 18KB)' : ''}",
        "text"         : "<pre>${logContent}</pre>"
      ]
    ]
  ]

  try {
    httpRequest(
      httpMode: 'POST',
      contentType: 'APPLICATION_JSON',
      requestBody: JsonOutput.toJson(payload),
      url: "${env.TEAMS_WEBHOOK_URL}",
      ignoreSslErrors: true
    )
    echo "Configure log sent to Teams webhook successfully."
  } catch (Exception webhookEx) {
    echo "WARNING: Failed to send configure log to webhook: ${webhookEx.getMessage()}"
  }
}



def cleanUpPod(params, stageType) {
  def namespace = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns" : "${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns"
  def podName = getConfigurePodName()

  def checkPodExistsCommand = "kubectl --kubeconfig kube-config get pod ${podName} -n ${namespace}"
  
  def podExistsStatus = 1
  if (isUnix()) {
      podExistsStatus = sh(script: checkPodExistsCommand, returnStatus: true)
  } else {
      podExistsStatus = bat(script: checkPodExistsCommand, returnStatus: true)
  }

  if (podExistsStatus == 0) {
    def deletePodCommand = "kubectl --kubeconfig kube-config delete pod ${podName} -n ${namespace}"
    if (isUnix()) { sh deletePodCommand } else { bat deletePodCommand }
    echo "Pod ${podName} has been deleted."
  } else {
    echo "Pod ${podName} not found, skipping deletion."
  }
}
// --------------------------------------- End Apply configure to system ---------------------------------------

// Create secret and deploy
def applySecrets(stageType) {
  def kubeConfigFile = stageType == 'DC' ? params.DC_KUBE_CONFIG_FILE : params.DR_KUBE_CONFIG_FILE

  withCredentials([file(credentialsId: kubeConfigFile, variable: 'KUBE_CONFIG_FILE')]) {
    def config = readFile file: KUBE_CONFIG_FILE 
    writeFile file: 'kube-config', text: config

    def CLIENT_SECRET_NAME = readJSON(text: params.CLIENT_SECRET_NAME)
    def CLIENT_LOCATION_VAULT = readJSON(text: params.CLIENT_LOCATION_VAULT)

    boolean shouldApply = !CLIENT_SECRET_NAME.contains('NOTUSE') && !CLIENT_LOCATION_VAULT.contains('NOTUSE')

    def namespace = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns" : "${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns"

    if (shouldApply) {
      def applyCommand = "echo \"Apply secret files\"\n"
      for (int i = 0; i < CLIENT_SECRET_NAME.size(); i++) {
        def secretName = CLIENT_SECRET_NAME[i]
        def fileName = CLIENT_LOCATION_VAULT[i]
        applyCommand += """
          kubectl --kubeconfig kube-config create secret generic ${secretName} --from-file=${params.PROJECT_NAME}-${params.ENVIRONMENT}/${fileName} -n ${namespace} --dry-run=client -o yaml | kubectl --kubeconfig kube-config apply -f -
        """
      }
      executeShellCommand(applyCommand)
    } else {
      echo "Skipping applyCommand due to 'NOTUSE' in CLIENT_SECRET_NAME or CLIENT_LOCATION_VAULT."
    }
  }
}


// ---------------------------- Unit Test before deploy new version ------------------------------------

def deployForUnitTest(stageType) {
  def kubeConfigFile = stageType == 'DC' ? params.DC_KUBE_CONFIG_FILE : params.DR_KUBE_CONFIG_FILE

  withCredentials([file(credentialsId: kubeConfigFile, variable: 'KUBE_CONFIG_FILE')]) {
    def config = readFile file: KUBE_CONFIG_FILE // FIX: Bỏ dấu nháy
    writeFile file: 'kube-config', text: config

    def podconfigContent = readFile "${params.PROJECT_NAME}-${params.ENVIRONMENT}/unit-test.yaml"
    podconfigContent = podconfigContent.replaceAll('IMAGE', "${params.IMAGETAG}")
    writeFile file: "${params.PROJECT_NAME}-${params.ENVIRONMENT}/unit-test-deployment.yaml", text: podconfigContent

    def namespace = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns" : "${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns"
    def deploymentName = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-${params.PROJECT_NAME}-${params.ENVIRONMENT}-unit-test-deployment" : "${params.PROJECT_NAME}-${params.ENVIRONMENT}-unit-test-deployment"

    def command = """
      echo "Setting up unit test deployment with image: ${params.IMAGETAG}"
      kubectl --kubeconfig kube-config --insecure-skip-tls-verify -n ${namespace} apply -f ${params.PROJECT_NAME}-${params.ENVIRONMENT}/unit-test-deployment.yaml
      kubectl --kubeconfig kube-config --insecure-skip-tls-verify -n ${namespace} rollout status deployment/${deploymentName}
    """
    executeShellCommand(command)
  }
}

def getPodName() {
    def namespace = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns" : "${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns"
    def appLabel = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-${params.PROJECT_NAME}-${params.ENVIRONMENT}-unit-test-app" : "${params.PROJECT_NAME}-${params.ENVIRONMENT}-unit-test-app"

    def getPodNameCommand = "kubectl --kubeconfig kube-config --insecure-skip-tls-verify -n ${namespace} get pods -l app=${appLabel} -o jsonpath='{.items[0].metadata.name}'"

    if (isUnix()) {
        return sh(script: getPodNameCommand, returnStdout: true).trim()
    } else {
        return powershell(script: getPodNameCommand, returnStdout: true).trim()
    }
}

def runUnitTestsOnPod(podName) {
    echo "Running unit tests on pod ${podName}"

    def namespace = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns" : "${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns"

    def testCommand = "kubectl --kubeconfig kube-config --insecure-skip-tls-verify -n ${namespace} exec ${podName} -- sh -c \"PORT=2255 npm run test\""

    def result = [:]

    if (isUnix()) {
        // sh() không hỗ trợ dùng cả returnStdout và returnStatus cùng lúc.
        // Dùng try/catch để bắt exit code khác 0.
        try {
            result.output = sh(script: testCommand, returnStdout: true).trim()
            result.status = 0
        } catch (Exception e) {
            // Khi lệnh thất bại, sh() ném exception. Lấy output từ message.
            result.output = e.getMessage() ?: 'Test execution failed'
            result.status = 1
        }
    } else {
        // Windows: Dùng powershell, kiểm tra $LASTEXITCODE riêng
        try {
            result.output = powershell(script: testCommand, returnStdout: true).trim()
            result.status = powershell(script: "echo \$LASTEXITCODE", returnStdout: true).trim() as Integer
        } catch (Exception e) {
            result.output = e.getMessage() ?: 'Test execution failed'
            result.status = 1
        }
    }

    return result
}

def sendLogToTeams(logContent, stageType) {
    def webhookUrl = "${env.TEAMS_WEBHOOK_URL}"
    def payload = [
        "@type"   : "MessageCard",
        "@context": "http://schema.org/extensions",
        "summary" : "Unit Test Log",
        "themeColor": "0072C6",
        "title"   : "Unit Test Log - ${stageType} ${params.ERP_APP_NAME} - ${params.PATH_NAME} - ${params.PROJECT_NAME} - ${params.ENVIRONMENT} - ${params.CLIENT_LOCATION}",
        "text"    : "Log output from the Unit Test process:\n```${logContent}```"
    ]
    
    httpRequest(
        httpMode: 'POST',
        contentType: 'APPLICATION_JSON',
        requestBody: JsonOutput.toJson(payload),
        url: webhookUrl,
        ignoreSslErrors: true
    )
}

def scaleDownUnitTestDeployment() {
    def namespace = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns" : "${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns"
    def deploymentName = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-${params.PROJECT_NAME}-${params.ENVIRONMENT}-unit-test-deployment" : "${params.PROJECT_NAME}-${params.ENVIRONMENT}-unit-test-deployment"

    def scaleCommand = """
      echo "Scaling down unit test deployment to 0 replicas"
      kubectl --kubeconfig kube-config --insecure-skip-tls-verify -n ${namespace} scale deployment/${deploymentName} --replicas=0
    """
    executeShellCommand(scaleCommand)
}

def deployToCluster(stageType) {
    def kubeConfigFile = stageType == 'DC' ? params.DC_KUBE_CONFIG_FILE : params.DR_KUBE_CONFIG_FILE

    withCredentials([file(credentialsId: kubeConfigFile, variable: 'KUBE_CONFIG_FILE')]) {
        def config = readFile file: KUBE_CONFIG_FILE
        writeFile file: 'kube-config', text: config

        def namespace = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns" : "${params.PROJECT_NAME}-${params.ENVIRONMENT}-ns"
        def deploymentName = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-${params.PROJECT_NAME}-${params.ENVIRONMENT}-deployment" : "${params.PROJECT_NAME}-${params.ENVIRONMENT}-deployment"
        def containerName = params.PATH_NAME?.trim() ? "${params.PATH_NAME}-${params.PROJECT_NAME}-${params.ENVIRONMENT}-container" : "${params.PROJECT_NAME}-${params.ENVIRONMENT}-container"

        def command = """
            echo "Release version: ${params.IMAGETAG}"
            echo "This release build at: ${params.TIMESTAMP} (GMT+7)"
            echo "Set image for deployment"
            kubectl --kubeconfig kube-config --insecure-skip-tls-verify -n ${namespace} get all
            kubectl --kubeconfig kube-config --insecure-skip-tls-verify -n ${namespace} set image deployment.apps/${deploymentName} ${containerName}=${params.IMAGETAG}
            kubectl --kubeconfig kube-config --insecure-skip-tls-verify -n ${namespace} rollout status deployment/${deploymentName}
        """
        executeShellCommand(command)
    }
}

def deployToERP(stageType) {
    withCredentials([sshUserPrivateKey(credentialsId: "${params.ERP_SSH_KEY}", keyFileVariable: 'SSH_KEY')]) {
        def remoteCommands = """
            echo "-----------------------------------------------------------------"
            echo "Deploying on project: ${params.PROJECT_NAME}"
            echo "Deploying on Environment: ${params.ENVIRONMENT}"
            echo "Domain used: ${params.ERP_URL}"
            echo "-----------------------------------------------------------------"
            cd /srv/bench/frappe-bench/apps/${params.ERP_APP_NAME}
            echo "-----------------------------------------------------------------"
            echo "Pull new version code from app ${params.ERP_APP_NAME}"
            git pull
            echo "-----------------------------------------------------------------"
            echo "Pull new version code from app ${params.ERP_APP_NAME} success!"
            bench --site ${params.ERP_URL} clear-cache
            bench --site ${params.ERP_URL} migrate
            echo "Migrate success"
            echo "-----------------------------------------------------------------"
            echo "Reload ${params.PROJECT_NAME}-${params.ENVIRONMENT}"
            pm2 reload ${params.PROJECT_NAME}-${params.ENVIRONMENT}
            echo "-----------------------------------------------------------------"
            echo "Reload ${params.PROJECT_NAME}-${params.ENVIRONMENT} success"
        """
        def command = """
            echo "Deploying ERP on server"
            ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no -p ${params.ERP_SSH_PORT} erpnext@${params.ERP_IP_ADDR} '${remoteCommands}'
        """
        executeShellCommand(command)
    }
}

def executeShellCommand(command) {
  def result
  if (env.OS_TYPE == 'linux') {
    result = sh(script: command, returnStatus: true)
  } else {
    result = bat(script: command, returnStatus: true)
  }

  if (result != 0) {
    error("Command failed: ${command}")
  }
}

def replaceVaultPipeline() {
  return """
    cd ${params.PROJECT_NAME}-${params.ENVIRONMENT}/
    python3 replace-vault-pipeline.py
    echo "Replace vault success"
  """
}

def workFlowProcess() {
  return """
    cd ${params.PROJECT_NAME}-${params.ENVIRONMENT}/
    python3 workflow-process-pipeline.py
    echo "workFlowProcess success"
  """
}

//------------------------------------------- Modulization ------------------------------------------------

// Function to clone modules
def cloneModule(moduleName, moduleInfo, GITLAB_ACCESS_TOKEN) {
    def moduleRepo = moduleInfo.split('@')[0]
    def moduleTag = moduleInfo.split('@')[1]  // Directly get the version tag from the input

    // Clone the module from GitLab with the provided token
    checkout([
        $class: 'GitSCM',
        branches: [[name: "tags/${moduleTag}"]],  // Use the tag directly
        doGenerateSubmoduleConfigurations: false,
        extensions: [
            [$class: 'RelativeTargetDirectory', relativeTargetDir: moduleName]
        ],
        submoduleCfg: [],
        userRemoteConfigs: [[
            url: "${moduleRepo.replace('https://', 'https://oauth2:'+GITLAB_ACCESS_TOKEN+'@')}"
        ]]
    ])

    echo "Cloned module: ${moduleName} from ${moduleRepo} at tag: ${moduleTag}"  // Debug print
    return [repo: moduleRepo, tag: moduleTag, dependencies: []]
}

// Function to process modules
def processModules(modulesToProcess, allModules, modules, baseModule) {
    while (!modulesToProcess.isEmpty()) {
        def currentModule = modulesToProcess.remove(0)
        echo "Cloning module: ${currentModule}"

        // Get the repository and version from modules
        def moduleRepo = modules[currentModule].split('@')[0]
        def moduleVersion = modules[currentModule].split('@')[1]

        if (!allModules.containsKey(currentModule)) {
            withCredentials([string(credentialsId: "${params.GITLAB_ACCESS_TOKEN}", variable: 'GITLAB_ACCESS_TOKEN')]) {
                // Clone the module and add to allModules
                allModules[currentModule] = cloneModule(currentModule, "${moduleRepo}@${moduleVersion}", GITLAB_ACCESS_TOKEN)
                echo "Checked out to tag: ${moduleVersion} for module: ${currentModule}"  // Debug print
            }
        }

        // Process dependencies with the correct version
        withCredentials([string(credentialsId: "${params.GITLAB_ACCESS_TOKEN}", variable: 'GITLAB_ACCESS_TOKEN')]) {
            processDependencies(currentModule, allModules, GITLAB_ACCESS_TOKEN, modulesToProcess, moduleVersion)
        }
    }
}

// Function to process dependencies
def processDependencies(currentModule, allModules, GITLAB_ACCESS_TOKEN, modulesToProcess, moduleVersion) {
    def packageJsonPath = "${currentModule}/package.json"

    if (fileExists(packageJsonPath)) {
        def packageJson = readJSON file: packageJsonPath
        echo "Checking dependencies for module: ${currentModule}"

        if (packageJson.modules) {
            packageJson.modules.each { depModule, depVersion ->

                if (depVersion.contains('@')) {  // Check if version contains '@'
                    def depRepo = depVersion.split('@')[0]
                    def depTag = depVersion.split('@')[1]

                    // If the repo does not have https, add it
                    if (!depRepo.startsWith('https://')) {
                        depRepo = "https://gitlab.com/${depRepo}"
                    }

                    if (!allModules.containsKey(depModule)) {
                        echo "Cloning dependency module: ${depModule} with tag: ${depTag} (from ${currentModule})"
                        allModules[depModule] = cloneModule(depModule, "${depRepo}@${depTag}", GITLAB_ACCESS_TOKEN)
                        modulesToProcess.add(depModule)
                    } else {
                        echo "Dependency module '${depModule}' already processed."
                    }
                } else {
                    echo "Skipping dependency '${depModule}' as it does not have a valid version."
                }
            }
        } else {
            echo "No dependencies found for module: ${currentModule}"
        }
    } else {
        echo "package.json not found for module: ${currentModule}"
    }
}

def determineFoldersToCopy(moduleDeploy) {
    if (moduleDeploy.contains('backend')) {
        return ["api/controllers", "api/models", "api/services", "api/policies"]
    } else if (moduleDeploy.contains('frontend')) {
        return ["src"]
    }
}

def mergeFiles(moduleDeploy, baseModule, allModules, projectName, environment) {
    def modulesToMerge = allModules.keySet().join(',')
    if (moduleDeploy.contains('backend')) {
        echo "Running backend-process.js to merge backend content..."
        sh """
            BASE_MODULE_PATH=${baseModule} \
            MODULES_TO_MERGE=${modulesToMerge} \
            node ${projectName}-${environment}/backend-process.js
        """
    } else if (moduleDeploy.contains('frontend')) {
        echo "Running frontend-process.js to merge frontend content..."
        sh """
            BASE_MODULE_PATH=${baseModule} \
            MODULES_TO_MERGE=${modulesToMerge} \
            node ${projectName}-${environment}/frontend-process.js
        """
    }
}

def copyFolders(allModules, baseModule, foldersToCopy, projectName, environment) {
    allModules.each { moduleName, moduleInfo ->
        foldersToCopy.each { folderPath ->
            def sourceFolder = "${moduleName}/${folderPath}"
            def targetFolder = "${baseModule}/${folderPath}"

            // Check for Gruntfile.js and copy if it exists
            def gruntfilePath = "${projectName}-${environment}/Gruntfile.js"
            if (fileExists(gruntfilePath)) {
                echo "Gruntfile.js found in ${projectName}-${environment}/, copying to ${baseModule}"
                sh "cp ${gruntfilePath} ${baseModule}/"
            } else {
                echo "Gruntfile.js not found in ${projectName}-${environment}/, skipping Gruntfile.js copy."
            }
            // Check for Dockerfile and copy if it exists
            def dockerfilePath = "${projectName}-${environment}/Dockerfile"
            if (fileExists(dockerfilePath)) {
                echo "Dockerfile found in ${projectName}-${environment}/, copying to ${baseModule}"
                sh "cp ${dockerfilePath} ${baseModule}/"
            } else {
                echo "Dockerfile not found in ${projectName}-${environment}/, skipping Dockerfile copy."
            }

            if (moduleName == baseModule) {
                echo "Skipping copy for base module: ${baseModule}"
                return
            }

            if (fileExists(sourceFolder)) {
                def filesInSourceFolder = sh(script: "ls -A ${sourceFolder}", returnStdout: true).trim()
                if (filesInSourceFolder) {
                    echo "Copying folder: ${sourceFolder} to ${targetFolder}"
                    sh "mkdir -p ${targetFolder} && cp -R ${sourceFolder}/* ${targetFolder}/"
                } else {
                    echo "No files in ${sourceFolder}, skipping copy."
                }
            } else {
                echo "Folder ${sourceFolder} not found, skipping copy."
            }
        }
    }
}

def moveFolders(baseModule, projectName, environment) {
    echo "Clean and Create folder for deploy"
    sh "rm -rf ${projectName}-${environment} && mv ${baseModule} ${projectName}-${environment}/"
}
