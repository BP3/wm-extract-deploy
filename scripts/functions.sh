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
    echo "Environment variable '$1' is not set"
    exit 1
  fi
}

checkRequiredEnvVarXor() {
  if [ -z "$(eval echo $"$1")" ] && [ -z "$(eval echo $"$2")" ]; then
    echo "Environment variable '$1' or '$2' must be set"
    exit 1
  elif [ -n "$(eval echo $"$1")" ] && [ -n "$(eval echo $"$2")" ]; then
    echo "Environment variable '$1' and '$2' cannot both be set"
    exit 1
  fi
}

checkRequiredEnvVarAnd() {
  if [ -n "$(eval echo $"$1")" ] && [ -z "$(eval echo $"$2")" ]; then
    echo "Environment variable '$2' must be set if '$1' is set"
    exit 1
  fi
}

addArg() {
  if [ -n "$2" ]; then
    if [ -z "${args}" ]; then
      args="$1 \"$2\""
    else
      args="${args} $1 \"$2\""
    fi
  fi
}

addEnvArg() {
  addArg "$1" "$(eval echo $"$2")"
}

addRequiredEnvArg() {
  checkRequiredEnvVar "$2"
  addEnvArg "$1" "$2"
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
  if [ -z "${COMMIT_MSG}" ]; then
    COMMIT_MSG="Updated by Camunda extract-deploy pipeline"
  fi
  if [ -z "${SKIP_CI}" ] || [ "${SKIP_CI}" = "true" ]; then
    # [skip ci] works across all the supported platforms
    COMMIT_MSG+=" [skip ci]"
  fi
  echo "${COMMIT_MSG}"
}

setupGit() {
  checkRequiredEnvVar GIT_USERNAME
  checkRequiredEnvVar GIT_USER_EMAIL

  # Use --global so changes are isolated to the container
  git config --global user.name "${GIT_USERNAME}"
  git config --global user.email "${GIT_USER_EMAIL}"

  # Add * to safe.directory to prevent ownership issues with mounted files
  git config --global --add safe.directory \*
}
