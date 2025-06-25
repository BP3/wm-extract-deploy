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
  if [ -z "$(eval echo $"$1")" ]; then
    echo "Environment variable '$1' is not set" >&2
    exit 1
  fi
}

getGitRepoUrl() {
  checkRequiredEnvVar CICD_ACCESS_TOKEN
  checkRequiredEnvVar CICD_REPOSITORY_PATH

  if [ -z "${CICD_PLATFORM}" ]; then
    CICD_PLATFORM=gitlab
  else
    CICD_PLATFORM=$(echo "${CICD_PLATFORM}" | tr "[:upper:]" "[:lower:]")
  fi

  URL="https://"
  if [ "${CICD_PLATFORM}" = "gitlab" ]; then
    if [ -z "${CICD_SERVER_HOST}" ]; then
      CICD_SERVER_HOST="gitlab.com"
    fi
    URL="${URL}gitlab-ci-token:"
  elif [ "${CICD_PLATFORM}" = "github" ]; then
    if [ -z "${CICD_SERVER_HOST}" ]; then
      CICD_SERVER_HOST="github.com"
    fi
  elif [ "${CICD_PLATFORM}" = "bitbucket" ]; then
    if [ -z "${CICD_SERVER_HOST}" ]; then
      CICD_SERVER_HOST="bitbucket.org"
    fi
    URL="${URL}x-token-auth:"
  fi

  URL="${URL}${CICD_ACCESS_TOKEN}@${CICD_SERVER_HOST}/${CICD_REPOSITORY_PATH}.git"

  echo "${URL}"
}

getCommitMessage() {
  if [ -z "${COMMIT_MSG}" ]; then
    COMMIT_MSG="Updated by Camunda extract-deploy pipeline"
  fi
  if [ -z "${SKIP_CI}" ] || [ "${SKIP_CI}" = "true" ]; then
    # [skip ci] works across all the supported platforms
    COMMIT_MSG="${COMMIT_MSG} [skip ci]"
  fi
  echo "${COMMIT_MSG}"
}

setupGit() {
  if [ -z "$NO_GIT_SETUP" ]; then
    checkRequiredEnvVar GIT_USERNAME
    checkRequiredEnvVar GIT_USER_EMAIL

    # Use --global so changes are isolated to the container
    git config --global user.name "${GIT_USERNAME}"
    git config --global user.email "${GIT_USER_EMAIL}"

    # Add * to safe.directory to prevent ownership issues with mounted files
    git config --global --add safe.directory \*
  fi
}
