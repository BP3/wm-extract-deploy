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
  if [ "$(eval echo "\$$1")" = "" ]; then
    echo "Environment variable '$1' is not set"
    exit 1
  fi
}

checkRequiredEnvVarXor() {
  if [ "$(eval echo "\$$1")" = "" ] && [ "$(eval echo "\$$2")" = "" ]; then
    echo "Environment variable '$1' or '$2' must be set"
    exit 1
  elif [ "$(eval echo "\$$1")" != "" ] && [ "$(eval echo "\$$2")" != "" ]; then
    echo "Environment variable '$1' and '$2' cannot both be set"
    exit 1
  fi
}

checkRequiredEnvVarAnd() {
  if [ "$(eval echo "\$$1")" != "" ] && [ "$(eval echo "\$$2")" = "" ]; then
    echo "Environment variable '$2' must be set if '$1' is set"
    exit 1
  fi
}

add_arg() {
  if [ "$2" != "" ]; then
    if [ "${args}" = "" ]; then
      args="$1 $2"
    else
      args="${args} $1 $2"
    fi
  fi
}

getGitRepoUrl() {
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
    COMMIT_MSG+=" [skip ci]"
  fi
  echo "${COMMIT_MSG}"
}
