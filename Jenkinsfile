import groovy.json.JsonOutput

def slackSendNotification(color = '', messageType = '', nonGenericMessage = false) {
  if (color != '' && messageType != '') {
    // slackSend
    withCredentials([[$class: 'StringBinding', credentialsId: 'SLACK_INTEGRATION_TOKEN', variable: 'SLACK_INTEGRATION_TOKEN']]) {
      if (nonGenericMessage) {
        message = messageType
      } else {
        message = "*${messageType}*: Job ${env.JOB_NAME} build ${env.BUILD_NUMBER}"
      }
      message += " (<${env.BUILD_URL}|Open>)"
      def payload = JsonOutput.toJson([
        "channel": "${env.SLACK_CHANNEL}",
        "attachments": [[
          "fallback": "${message}",
          "color": "${color}",
          "fields": [[
            "short": false,
            "value": "${message}",
          ]],
          "mrkdwn_in": [
            "pretext",
            "text",
            "fields",
          ]
        ]]
      ])
      apiUrl = "https://${env.SLACK_TEAM_DOMAIN}.slack.com/services/hooks/jenkins-ci?token=${env.SLACK_INTEGRATION_TOKEN}"
      response = sh(returnStdout: true,
        script: "curl -s -H \"Content-type: application/json\" -X POST -d '${payload}' ${apiUrl}"
      ).trim()
    }
  }
}

pipeline {
  agent {
    node { label "${WORKER}" }
  }
  environment {
    registryCredential = 'jenkins-artifactory'
    dockerImage = ''
    SLACK_CHANNEL = '#dev-infra-updates'
  }
  stages {
    stage('ShellCheck') {
      steps {
        script {
          sh "cd configurator && make shellcheck"
        }
      }
    }
    stage('Test') {
      steps{
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
          script {
              sh(
                "cd configurator && " +
                "IMAGE_NAME=${env.ARTIFACTORY_URL}/configurator:${env.BRANCH_NAME}.${env.BUILD_NUMBER} make test"
              )
          }
        }
      }
      post {
        cleanup {
          withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
            script {
              sh("docker rmi ${env.ARTIFACTORY_URL}/configurator:${env.BRANCH_NAME}.${env.BUILD_NUMBER}")
            }
          }
        }
      }
    }
    stage('Test uber_tar') {
      steps{
        script {
          docker.withRegistry("https://quay.io", "QUAY") {
            sh(
              "cd configurator && " +
              "make test_uber_tar"
            )
          }
        }
      }
      post {
        cleanup {
          script {
            sh "cd configurator && make clean || /bin/true"
            sh "docker rmi -f \$(docker images -qa) || /bin/true"
          }
        }
      }
    }
    stage('Push uber_tar') {
      // TODO
      // This will be guarded with the proper branch before this is merged.
      steps{
        withCredentials([
          string(credentialsId: 'artifactory-api-key', variable: 'ARTIFACTORY_API_KEY'),
          string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')
        ]) {
          script {
            docker.withRegistry("https://quay.io", "QUAY") {
              sh(
                "cd configurator && " +
                "VERSION=${env.BRANCH_NAME}.${env.BUILD_NUMBER} make create_uber_tar push_uber_tar"
              )
            }
          }
        }
      }
      post {
        cleanup {
          script {
            sh "cd configurator && make clean || /bin/true"
            sh("docker rmi -f \$(docker images -qa) || /bin/true")
          }
        }
      }
    }
    stage('Push') {
      when {
        branch 'Templating_k8s_configurations'
      }
      steps{
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
          script {
              dockerImage = docker.build("${env.ARTIFACTORY_URL}/configurator:${env.BRANCH_NAME}.${env.BUILD_NUMBER}", './configurator/')
              sh("docker run --rm --entrypoint /sysdig-chart/test.sh ${env.ARTIFACTORY_URL}/configurator:${env.BRANCH_NAME}.${env.BUILD_NUMBER}")
              docker.withRegistry("https://${env.ARTIFACTORY_URL}", registryCredential) {
                dockerImage.push()
                dockerImage.push('latest')
              }
          }
        }
      }
      post {
        success {
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
            script {
              slackSendNotification("${env.SLACK_COLOR_GOOD}", "Pushed docker image: ${env.ARTIFACTORY_URL}/configurator:${env.BRANCH_NAME}.${env.BUILD_NUMBER}")
            }
          }
        }
        cleanup {
        withCredentials([string(credentialsId: 'ARTIFACTORY_URL', variable: 'ARTIFACTORY_URL')]) {
            script {
              sh("docker rmi ${env.ARTIFACTORY_URL}/configurator:${env.BRANCH_NAME}.${env.BUILD_NUMBER}")
            }
          }
        }
      }
    }
  }
  post {
    failure {
      script {
        slackSendNotification("${env.SLACK_COLOR_DANGER}", "FAILED")
      }
    }
    success {
      script {
        slackSendNotification("${env.SLACK_COLOR_GOOD}", "SUCCESS")
      }
    }
  }
}
