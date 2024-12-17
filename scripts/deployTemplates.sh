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
checkRequiredEnvVar GIT_USERNAME
checkRequiredEnvVar GIT_USER_EMAIL
checkRequiredEnvVar CAMUNDA_WM_CLIENT_ID
checkRequiredEnvVar CAMUNDA_WM_CLIENT_SECRET

# Use --global so changes are isolated to the container
git config --global set user.name "${GIT_USERNAME}"
git config --global set user.email "${GIT_USER_EMAIL}"

git fetch

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
add_arg --authentication-host "${CAMUNDA_WM_AUTH}"
add_arg --ssl "${CAMUNDA_WM_SSL}"

python "${SCRIPT_DIR}"/deploy_connector_templates.py "${args}"

git add config.*

git commit -m "$(getCommitMessage)"

git push "$(getGitRepoUrl)" "${CICD_BRANCH}"
