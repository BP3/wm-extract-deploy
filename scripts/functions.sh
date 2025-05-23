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
  if [ "$2" == "" ]; then
    echo "EnvVar '$1' is not set"
    exit 1
  fi
}

getGitLabUrl() {
  echo "https://gitlab-ci-token:$1@$2/$3.git"
}

getGitHubUrl(){
  echo "https://$1@$2/$3.git"
}

getBitBucketUrl() {
  echo "https://x-token-auth:$1@$2/$3.git"
}

getUrl() {
  CICD_PLATFORM=$(echo "$1" | tr "[:upper:]" "[:lower:]")
  CICD_SERVER_HOST=$2
  CICD_ACCESS_TOKEN=$3
  CICD_REPOSITORY_PATH=$4

  URL=""
  if [ $CICD_PLATFORM = "gitlab" ]; then

    URL="$(getGitLabUrl "$CICD_ACCESS_TOKEN" "$CICD_SERVER_HOST" "$CICD_REPOSITORY_PATH")"

  elif [ "$CICD_PLATFORM" = "github" ]; then

    URL="$(getGitHubUrl "$CICD_ACCESS_TOKEN" "$CICD_SERVER_HOST" "$CICD_REPOSITORY_PATH")"

  elif [ "$CICD_PLATFORM" = "bitbucket" ]; then

    URL="$(getBitBucketUrl "$CICD_ACCESS_TOKEN" "$CICD_SERVER_HOST" "$CICD_REPOSITORY_PATH")"

  fi

  echo "$URL"
}

setGitUser() {
  checkRequiredEnvVar GIT_USERNAME "$GIT_USERNAME"
  checkRequiredEnvVar GIT_USER_EMAIL "$GIT_USER_EMAIL"

  git config --global user.name "$GIT_USERNAME"
  git config --global user.email $GIT_USER_EMAIL
}
