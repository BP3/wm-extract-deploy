#!/bin/sh

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

checkRequiredEnvVar MODEL_PATH

GIT_REPO="$(getGitRepoUrl)"

git config set user.name "${GIT_USERNAME}"
git config set user.email "${GIT_USER_EMAIL}"

if [ "${CICD_BRANCH}" = "" ]; then
  CICD_BRANCH=main
fi
echo "Checkout branch: ${CICD_BRANCH}"
git checkout -B "${CICD_BRANCH}"

# Delete BPM artifacts to propagate deletions from Web Modeller
git rm --ignore-unmatch "${MODEL_PATH}"/*.bpmn
git rm --ignore-unmatch "${MODEL_PATH}"/*.dmn
git rm --ignore-unmatch "${MODEL_PATH}"/*.form

python "${SCRIPT_DIR}"/extract.py

git add -- *.bpmn  2>/dev/null
git add -- *.dmn  2>/dev/null
git add -- *.form  2>/dev/null
git add -- config.*  2>/dev/null
git status

git commit -m "$(getCommitMessage)"

git push "${GIT_REPO}" "${CICD_BRANCH}"
