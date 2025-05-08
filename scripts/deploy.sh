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

git config --global user.name "$GIT_USERNAME"
git config --global user.email $GIT_USER_EMAIL

git fetch

if [ "$CICD_BRANCH" = "" ]; then
    git -c advice.detachedHead=false checkout $CICD_BRANCH
fi
if [ "$PROJECT_TAG" = "" ]; then
    git -c advice.detachedHead=false checkout tags/"$PROJECT_TAG"
fi

python $SCRIPT_DIR/deploy.py
