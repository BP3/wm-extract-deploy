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
checkRequiredEnvVar OAUTH2_TOKEN_URL
checkRequiredEnvVar OAUTH_PLATFORM

# Use --global so changes are isolated to the container
git config --global set user.name "${GIT_USERNAME}"
git config --global set user.email "${GIT_USER_EMAIL}"
# Add * to safe.directory to prevent ownership issues with mounted files
git config --global --add safe.directory \*

if [ "${CICD_BRANCH}" = "" ]; then
  CICD_BRANCH=main
fi
echo "Checkout branch: ${CICD_BRANCH}"
git checkout -B "${CICD_BRANCH}"

# Delete BPM artifacts to propagate deletions from Web Modeller
git rm --ignore-unmatch "${MODEL_PATH}"/*.bpmn
git rm --ignore-unmatch "${MODEL_PATH}"/*.dmn
git rm --ignore-unmatch "${MODEL_PATH}"/*.form

args=
add_arg --model-path "${MODEL_PATH}"
add_arg --client-id "${CAMUNDA_WM_CLIENT_ID}"
add_arg --client-secret "${CAMUNDA_WM_CLIENT_SECRET}"
add_arg --host "${CAMUNDA_WM_HOST}"
add_arg --oauth2_token_url "${OAUTH2_TOKEN_URL}"
add_arg --oauth2_platform "${OAUTH2_PLATFORM}"
add_arg --ssl "${CAMUNDA_WM_SSL}"
add_arg --config-file "${WM_PROJECT_METADATA_FILE}"
add_arg --project "${CAMUNDA_WM_PROJECT}"

python "${SCRIPT_DIR}"/extract.py ${args}

git add -- *.bpmn  2>/dev/null || true
git add -- *.dmn  2>/dev/null || true
git add -- *.form  2>/dev/null || true
git add -- config.*  2>/dev/null || true
git status

git commit -m "$(getCommitMessage)"

git push "$(getGitRepoUrl)" "${CICD_BRANCH}"
