#!/bin/sh -ex

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

args=
addEnvArg --model-path MODEL_PATH
addRequiredEnvArg --client-id ZEEBE_CLIENT_ID
addRequiredEnvArg --client-secret ZEEBE_CLIENT_SECRET
checkRequiredEnvVarAnd CAMUNDA_CLUSTER_ID CAMUNDA_CLUSTER_REGION
checkRequiredEnvVarXor CAMUNDA_CLUSTER_ID CAMUNDA_CLUSTER_HOST
checkRequiredEnvVarXor CAMUNDA_CLUSTER_REGION CAMUNDA_CLUSTER_PORT
addEnvArg --cluster-id CAMUNDA_CLUSTER_ID
addEnvArg --cluster-region CAMUNDA_CLUSTER_REGION
checkRequiredEnvVarAnd CAMUNDA_CLUSTER_HOST CAMUNDA_CLUSTER_PORT
addEnvArg --cluster-host CAMUNDA_CLUSTER_HOST
addEnvArg --cluster-port CAMUNDA_CLUSTER_PORT
addEnvArg --tenant CAMUNDA_TENANT_ID

if [ -z "$NO_GIT_FETCH" ]; then
  setupGit

  if [ -n "$PROJECT_TAG" ]; then
    GIT_REF=tags/"${PROJECT_TAG}"
  else
    if [ -z "$CICD_BRANCH" ]; then
        CICD_BRANCH=main
    fi
    GIT_REF="${CICD_BRANCH}"
  fi
  git fetch origin "${GIT_REF}"
  git -c advice.detachedHead=false checkout "${GIT_REF}"
fi

python "${SCRIPT_DIR}"/deploy.py ${args}
