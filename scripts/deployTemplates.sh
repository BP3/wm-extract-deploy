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

setupGit

if [ -z "$CICD_BRANCH" ]; then
  CICD_BRANCH=main
fi
echo "Checkout branch: $CICD_BRANCH"
git checkout -B $CICD_BRANCH

python "${SCRIPT_DIR}"/deploy_connector_templates.py
echo "Script Complete, Committing Config."

git add config.*

git commit -m "$(getCommitMessage)"

git push "${GIT_REPO_URL}" "${CICD_BRANCH}"
