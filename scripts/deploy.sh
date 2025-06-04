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

if [ -z "$NO_GIT" ] && [ -z "$NO_GIT_FETCH" ]; then
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

python "${SCRIPT_DIR}"/deploy.py "$@"
