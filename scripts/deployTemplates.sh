#!/bin/bash -e

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

setGitUser

if [ "$CICD_BRANCH" = "" ]; then
  CICD_BRANCH=main
fi
echo "Checkout branch: $CICD_BRANCH"
git checkout -B $CICD_BRANCH

python $SCRIPT_DIR/deploy_connector_templates.py
echo "Script Complete, Committing Config."

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
