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

GIT_REPO="$(getGitRepoUrl)"

git config set user.name "${GIT_USERNAME}"
git config set user.email "${GIT_USER_EMAIL}"

git fetch

git checkout main

python "${SCRIPT_DIR}"/deploy_connector_templates.py

git add config.*

git commit -m "$(getCommitMessage)"

git push "${GIT_REPO}" "${CICD_BRANCH}"
