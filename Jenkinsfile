#!groovy

def gitClean() {
  // inspired by: https://issues.jenkins-ci.org/browse/JENKINS-31924
  // https://issues.jenkins-ci.org/browse/JENKINS-32540
  // The sequence of reset --hard and clean -fdx first
  // in the root and then using submodule foreach
  // is based on how the Jenkins Git SCM clean before checkout
  // feature works.
  sh 'git reset --hard'
  sh 'git clean -ffdx'
}

// Build the name:tag for a docker image where the tag is the checksum
// computed from a specified file.
def imageName(name, filenames) {
  // If this is extended to support multiple files, be wary of:
  // https://issues.jenkins-ci.org/browse/JENKINS-26481
  // closures don't really work.

  // Suck in the contents of the file and then hash the result.
  def contents = "";
  for (int i=0; i<filenames.size(); i++) {
    print "reading ${filenames[i]}"
    def content = readFile(filenames[i])
    print "read ${filenames[i]}"
    contents = contents + content
  }

  print "hashing ${name}"
  def tag = java.security.MessageDigest.getInstance("MD5").digest(contents.bytes).encodeHex().toString()
  print "hashed ${name}"
  def result = "${name}:${tag}"
  print "computed image name ${result}"
  return result
}

isUserBranch = true
if (env.BRANCH_NAME == 'master') {
  isUserBranch = false
} else if (env.BRANCH_NAME ==~ /^\d+\.\d+\.\d+$/) {
  isUserBranch = false
}

messagePrefix = "<${env.JOB_URL}|rsconnect-jupyter pipeline> build <${env.BUILD_URL}|${env.BUILD_DISPLAY_NAME}>"

slackChannelPass = "#rsconnect-bots"
slackChannelFail = "#rsconnect"
if (isUserBranch) {
  slackChannelFail = "#rsconnect-bots"
}

nodename = 'docker'
if (isUserBranch) {
  // poor man's throttling for user branches.
  nodename = 'connect-branches'
}

def build_args() {
  def uid = sh (script: 'id -u jenkins', returnStdout: true).trim()
  def gid = sh (script: 'id -g jenkins', returnStdout: true).trim()
  def image = 'continuumio/miniconda3:4.4.10'
  return " --build-arg PY_VERSION=3 --build-arg BASE_IMAGE=${image} --build-arg NB_UID=${uid} --build-arg NB_GID=${gid} "
}

try {
  node(nodename) {
    timestamps {
      checkout scm
      gitClean()

      // If we want to link to the commit, we need to drop down to shell. This
      // means that we need to be inside a `node` and after checking-out code.
      // https://issues.jenkins-ci.org/browse/JENKINS-26100 suggests this workaround.
      gitSHA = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
      shortSHA = gitSHA.take(6)

      // Update our Slack message metadata with commit info once we can obtain it.
      messagePrefix = messagePrefix + " of <https://github.com/rstudio/rsconnect-jupyter/commit/${gitSHA}|${shortSHA}>"

      // Looking up the author also demands being in a `node`.
      gitAuthor = sh(returnStdout: true, script: 'git --no-pager show -s --format="%aN" HEAD').trim()

      def dockerImage
      stage('prepare environment') {
        dockerImage = pullBuildPush(
          image_name: 'jenkins/rsconnect-jupyter',
          image_tag: 'python3',
          build_arg_nb_uid: 'JENKINS_UID',
          build_arg_nb_gid: 'JENKINS_GID',
          build_args: build_args(),
          push: !isUserBranch
        )
      }

      dockerImage.inside() {
        stage('package') {
          print "building python wheel package"
          sh 'make dist'
          archiveArtifacts artifacts: 'dist/*.whl'
        }
      }
    }
  }

  // Slack message includes username information.
  message = "${messagePrefix} by ${gitAuthor} passed"
  slackSend channel: slackChannelPass, color: 'good', message: message
} catch(err) {
  // Slack message includes username information. When master/release fails,
  // CC the whole connect team.
  slackNameFail = "unknown"
  if (!isUserBranch) {
    slackNameFail = "${gitAuthor} (cc @kenny)"
  }

  message = "${messagePrefix} by ${slackNameFail} failed: ${err}"
  slackSend channel: slackChannelFail, color: 'bad', message: message
  throw err
}