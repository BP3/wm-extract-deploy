#!/bin/sh -e

############################################################################
#
# Licensed Materials - Property of BP3
#
# Web Modeler Extract Deploy (WMED)
#
# Copyright © BP3 Global Inc. 2025. All Rights Reserved.
# This software is subject to copyright protection under
# the laws of the United States and other countries.
#
############################################################################

############################################################################
#
# This file is intended to provide the basis of a reusable template.
# The test itself consists of running the following functions
#
#     _setup
#
#     Given
#     When
#     Then
#
#     _teardown
#
# The function implementation will obviously change from file to file (test to test).
#
############################################################################

TESTNAME=`basename $0 .sh`
IMAGE_NAME=ghcr.io/bp3/wm-extract-deploy
IMAGE_REF=$1

# Load reusable extract functions
. $TESTSDIR/extract-functions.sh

_setup () {
  # Make sure everything is clean before we start
  if [ -d $TESTSDIR/$TESTNAME ]; then
    rm -rf $TESTSDIR/$TESTNAME
  fi

  get_network_id
  echo "Network Id: $network_id"
}

_teardown () {
  :
#  docker container stop wmed
#  docker container rm wmed
  # Or we could leave everything behind so that it can be checked later
#  if [ -d $TESTSDIR/$TESTNAME ]; then
#    rm -rf $TESTSDIR/$TESTNAME
#  fi
}

Given () {
  echo "$TESTNAME: Given"
  # 1.  Need a local version of what project will look like - maybe in a separate directory
  # 2.  Will first need to create/import project into Web Modeler

  # Just trying some stuff out. This probably needs to go into functions later
  # Assumes that we have already run 'docker-compose -f ../extract-compose.yaml up -d'

  get_access_token

  # Big picture is
  #
  #   Project
  #     Readme[.md]
  #     process[.bpmn]
  #     Folder1
  #       Readme[.md]
  #       process1[.bpmn]
  #       process2.wmedIgnore[.bpmn]
  #     Folder2.wmedIgnore
  #       Readme[.md]
  #       process[.bpmn]

#  create_project "Project"
##  add_collaborator demo@acme.com $project_id
#  create_file Readme $project_id files/Readme.md markdown
#  create_file process $project_id files/process.bpmn bpmn
#
#  create_folder Folder1 $project_id
#  create_file Readme $project_id files/Readme.md markdown $folder_id
#  create_file process1 $project_id files/process.bpmn bpmn $folder_id
#  create_file process2-wmedIgnore $project_id files/process.bpmn bpmn $folder_id
#
#  create_folder Folder2.wmedIgnore $project_id
#  create_file Readme $project_id files/Readme.md markdown $folder_id
#  create_file process $project_id files/process.bpmn bpmn $folder_id
}

When () {
  echo "$TESTNAME: When"
  mkdir -p $TESTSDIR/$TESTNAME

  # This test requires us to run in Git mode because that is when the MODEL_PATH
  # is checked, so we have to set GIT related env vars to pass the argument validation stage
  docker run -d $DOCKER_TTY_OPTS --name wmed --net=host -w /local \
    -e APP=/app \
    -e OAUTH2_CLIENT_ID=wmed -e OAUTH2_CLIENT_SECRET=wmed \
    -e OAUTH2_TOKEN_URL=http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token \
    -e CAMUNDA_WM_PROJECT="$project_id" \
    -e CAMUNDA_WM_HOST="localhost:8070" \
    -e CICD_BRANCH="$GITHUB_REF" \
    -e CICD_ACCESS_TOKEN="${GITHUB_TOKEN}" \
    -e CICD_REPOSITORY_PATH="$GITHUB_WORKSPACE" \
    -e CICD_SERVER_HOST="$GITHUB_SERVER_URL" \
      --entrypoint /bin/sh $IMAGE_NAME:$IMAGE_REF

  echo Sleep for a few seconds whilst docker container comes up ...
  sleep 5

  docker exec $DOCKER_TTY_OPTS -w /local wmed /app/scripts/extractDeploy.sh extract
}

Then () {
  echo "$TESTNAME: Then"

  model_path=$(echo docker exec wmed printenv MODEL_PATH)
  echo "The MODEL_PATH has been set to ${model_path}"
}

############################################################################
# So, the actual test is

_setup

  Given
  When
  Then

_teardown
