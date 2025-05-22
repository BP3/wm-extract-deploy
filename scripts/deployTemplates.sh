#!/bin/sh -e

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
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
. "${SCRIPT_DIR}"/functions.sh

GIT_REPO_URL="$(getGitRepoUrl)"
args=
addEnvArg --model-path MODEL_PATH
addRequiredEnvArg --client-id CAMUNDA_WM_CLIENT_ID
addRequiredEnvArg --client-secret CAMUNDA_WM_CLIENT_SECRET
addEnvArg --host CAMUNDA_WM_HOST
addRequiredEnvArg --oauth2-token-url OAUTH2_TOKEN_URL
addRequiredEnvArg --oauth2-platform OAUTH_PLATFORM
addEnvArg --ssl CAMUNDA_WM_SSL

setupGit

if [ -z "$CICD_BRANCH" ]; then
  CICD_BRANCH=main
fi
echo "Checkout branch: $CICD_BRANCH"
git checkout -B $CICD_BRANCH

python "${SCRIPT_DIR}"/deploy_connector_templates.py "${args}"
echo "Script Complete, Committing Config."

git add config.*

git commit -m "$(getCommitMessage)"

git push "${GIT_REPO_URL}" "${CICD_BRANCH}"
