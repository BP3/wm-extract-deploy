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

checkRequiredEnvVar CICD_ACCESS_TOKEN
checkRequiredEnvVar CICD_REPOSITORY_PATH
checkRequiredEnvVar CAMUNDA_WM_CLIENT_ID
checkRequiredEnvVar CAMUNDA_WM_CLIENT_SECRET
checkRequiredEnvVar OAUTH2_TOKEN_URL
checkRequiredEnvVar OAUTH_PLATFORM

setGitUser

# Add * to safe.directory to prevent ownership issues with mounted files
git config --global --add safe.directory \*

if [ "$CICD_BRANCH" = "" ]; then
  CICD_BRANCH=main
fi
echo "Checkout branch: $CICD_BRANCH"
git checkout -B $CICD_BRANCH

if [ "${CICD_BRANCH}" = "" ]; then
  CICD_BRANCH=main
fi
echo "Checkout branch: ${CICD_BRANCH}"
git checkout -B "${CICD_BRANCH}"

args=
add_arg --model-path "${MODEL_PATH}"
add_arg --client-id "${CAMUNDA_WM_CLIENT_ID}"
add_arg --client-secret "${CAMUNDA_WM_CLIENT_SECRET}"
add_arg --host "${CAMUNDA_WM_HOST}"
add_arg --oauth2-token-url "${OAUTH2_TOKEN_URL}"
add_arg --oauth2-platform "${OAUTH_PLATFORM}"
add_arg --ssl "${CAMUNDA_WM_SSL}"

python "${SCRIPT_DIR}"/deploy_connector_templates.py "${args}"
echo "Script Complete, Committing Config."

git add config.*

git commit -m "$(getCommitMessage)"

git push "$(getGitRepoUrl)" "${CICD_BRANCH}"
