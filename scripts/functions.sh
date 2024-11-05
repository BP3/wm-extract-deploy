############################################################################
#
# Licensed Materials - Property of BP3
#
# Web Modeler Extract Deploy (WMED)
#
# Copyright © BP3 Global Inc. 2024. All Rights Reserved.
# This software is subject to copyright protection under
# the laws of the United States and other countries.
#
############################################################################

checkRequiredEnvVar() {
  if [ "$(eval \$$1)" = "" ]; then
    echo "Environment variable '$1' is not set"
    exit 1
  fi
}

getGitRepoUrl() {
  checkRequiredEnvVar CICD_ACCESS_TOKEN
  checkRequiredEnvVar CICD_REPOSITORY_PATH

  if [ "${CICD_PLATFORM}" = "" ]; then
    CICD_PLATFORM=gitlab
  else
    CICD_PLATFORM=$(echo "${CICD_PLATFORM}" | tr "[:upper:]" "[:lower:]")
  fi

  URL="https://"
  if [ "${CICD_PLATFORM}" = "gitlab" ]; then
    if [ -z "${CICD_SERVER_HOST}" ]; then
      CICD_SERVER_HOST="gitlab.com"
    fi
    URL+="gitlab-ci-token:"
  elif [ "${CICD_PLATFORM}" = "github" ]; then
    if [ -z "${CICD_SERVER_HOST}" ]; then
      CICD_SERVER_HOST="github.com"
    fi
    URL+=""
  elif [ "${CICD_PLATFORM}" = "bitbucket" ]; then
    if [ -z "${CICD_SERVER_HOST}" ]; then
      CICD_SERVER_HOST="bitbucket.org"
    fi
    URL+="x-token-auth:"
  fi

  URL+="${CICD_ACCESS_TOKEN}@${CICD_SERVER_HOST}/${CICD_REPOSITORY_PATH}.git"

  echo "${URL}"
}

getCommitMessage() {
  if [ "${COMMIT_MSG}" = "" ]; then
    COMMIT_MSG="Updated by Camunda extract-deploy pipeline"
  fi
  if [ "${SKIP_CI}" = "" ] || [ "${SKIP_CI}" = "true" ]; then
    # [skip ci] works across all the supported platforms
    COMMIT_MSG="${COMMIT_MSG} [skip ci]"
  fi
  echo "${COMMIT_MSG}"
}
