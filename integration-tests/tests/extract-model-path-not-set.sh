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
  docker container stop wmed
  docker container rm wmed

  # Or we could leave everything behind so that it can be checked later
#  if [ -d $TESTSDIR/$TESTNAME ]; then
#    rm -rf $TESTSDIR/$TESTNAME
#  fi
}

Given () {
  echo "$TESTNAME: Given"

  get_access_token

  # Give us something to extract although we are not testing this specifically
  # as that test case is handled in other tests
  create_project "Project"
  create_file process $project_id files/process.bpmn bpmn
}

When () {
  echo "$TESTNAME: When"
  mkdir -p $TESTSDIR/$TESTNAME

  # Running this in interactive mode so we can run the extract script and check for the MODEL_PATH
  # env var, otherwise if we run it without overriding the entry point the container will have exited
  # before we get a chance to check
  docker run -d "$DOCKER_TTY_OPTS" --name wmed --net=host -w /local \
    -e APP=/app -e NO_GIT=true \
    -e OAUTH2_CLIENT_ID=wmed -e OAUTH2_CLIENT_SECRET=wmed \
    -e OAUTH2_TOKEN_URL=http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token \
    -e CAMUNDA_WM_PROJECT="$project_id" \
    -e CAMUNDA_WM_HOST="localhost:8070" \
      --entrypoint /bin/sh $IMAGE_NAME:$IMAGE_REF

  echo Sleep for a few seconds whilst docker container comes up ...
  sleep 5

  docker exec "$DOCKER_TTY_OPTS" -w /local wmed /app/scripts/extractDeploy.sh extract < /dev/null
}

Then () {
  echo "$TESTNAME: Then"

  docker exec "$DOCKER_TTY_OPTS" wmed printenv MODEL_PATH
  model_path=$(docker exec "$DOCKER_TTY_OPTS" wmed printenv MODEL_PATH)
  echo "The MODEL_PATH has been set to $model_path"

  assert_equals "$model_path" "."
}

############################################################################
# So, the actual test is

_setup

  Given
  When
  Then

_teardown
