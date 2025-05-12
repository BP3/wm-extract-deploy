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


if [ -z "$NO_GIT_FETCH" ]; then

  setGitUser
  git fetch

  if [ ! -z "$PROJECT_TAG" ]; then
    git -c advice.detachedHead=false checkout tags/"$PROJECT_TAG"
  else
    if [ "$CICD_BRANCH" = "" ]; then
        CICD_BRANCH=main
    fi
    git -c advice.detachedHead=false checkout $CICD_BRANCH
  fi

fi

python $SCRIPT_DIR/deploy.py
