#!/bin/bash

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

source $SCRIPT_DIR/functions.sh

checkRequiredEnvVar CICD_ACCESS_TOKEN               "$CICD_ACCESS_TOKEN"
checkRequiredEnvVar CICD_REPOSITORY_PATH            "$CICD_REPOSITORY_PATH"

if [ "$CICD_PLATFORM" = "" ]; then
  CICD_PLATFORM=gitlab
  if [ -z "$CICD_SERVER_HOST" ]; then
    CICD_SERVER_HOST="gitlab.com"
  fi
elif [ "$CICD_PLATFORM" = "github" ]; then
  if [ -z "$CICD_SERVER_HOST" ]; then
    CICD_SERVER_HOST="github.com"
  fi
elif [ "$CICD_PLATFORM" = "bitbucket" ]; then
  if [ -z "$CICD_SERVER_HOST" ]; then
    CICD_SERVER_HOST="bitbucket.org"
  fi
fi
echo "The CI/CD platform is: $CICD_PLATFORM"

git config --global user.name "$GIT_USERNAME"
git config --global user.email $GIT_USER_EMAIL

git fetch

git checkout main

python $SCRIPT_DIR/deployConnectorTemplates.py
if [ $? -ne 0 ]; then
  exit 1
fi

git add config.*

# [skip ci] works across all the supported platforms
if [ "$COMMIT_MSG" = "" ]; then
  COMMIT_MSG="Updated by Camunda extract-deploy pipeline"
fi
if [ "$SKIP_CI" = "" -o "$SKIP_CI" = "true" ]; then
  COMMIT_MSG="${COMMIT_MSG} [skip ci]"
fi

git commit -m "${COMMIT_MSG}"

git push "$(getUrl "$CICD_PLATFORM" "$CICD_SERVER_HOST" "$CICD_ACCESS_TOKEN" "$CICD_REPOSITORY_PATH")" $CICD_BRANCH
