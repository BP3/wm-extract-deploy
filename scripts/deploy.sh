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

checkRequiredEnvVar MODEL_PATH
checkRequiredEnvVar ZEEBE_CLIENT_ID
checkRequiredEnvVar ZEEBE_CLIENT_SECRET
checkRequiredEnvVarXor CAMUNDA_CLUSTER_ID CAMUNDA_CLUSTER_HOST
checkRequiredEnvVarXor CAMUNDA_CLUSTER_REGION CAMUNDA_CLUSTER_PORT
checkRequiredEnvVarAnd CAMUNDA_CLUSTER_ID CAMUNDA_CLUSTER_REGION
checkRequiredEnvVarAnd CAMUNDA_CLUSTER_HOST CAMUNDA_CLUSTER_PORT

if [ -z "$NO_GIT_FETCH" ]; then
  setGitUser
  git fetch

  if [ ! -z "$PROJECT_TAG" ]; then
    git -c advice.detachedHead=false checkout tags/"${PROJECT_TAG}"
  else
    if [ "$CICD_BRANCH" = "" ]; then
        CICD_BRANCH=main
    fi
    git -c advice.detachedHead=false checkout $CICD_BRANCH
  fi
fi

args=
add_arg --model-path "${MODEL_PATH}"
add_arg --client-id "${ZEEBE_CLIENT_ID}"
add_arg --client-secret "${ZEEBE_CLIENT_SECRET}"
add_arg --cluster-id "${CAMUNDA_CLUSTER_ID}"
add_arg --cluster-region "${CAMUNDA_CLUSTER_REGION}"
add_arg --cluster-host "${CAMUNDA_CLUSTER_HOST}"
add_arg --cluster-port "${CAMUNDA_CLUSTER_PORT}"
add_arg --tenant "${CAMUNDA_TENANT_ID}"

python "${SCRIPT_DIR}"/deploy.py ${args}
