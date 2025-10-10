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
. $TESTSDIR/deploy-functions.sh

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
  # Or we could leave everything behind so that it can be checked later
#  if [ -d $TESTSDIR/$TESTNAME ]; then
#    rm -rf $TESTSDIR/$TESTNAME
#  fi
}

Given () {
  echo "$TESTNAME: Given"

  # Just trying some stuff out. This probably needs to go into functions later
  # Assumes that we have already run 'docker-compose -f ../deploy-compose.yaml up -d'

  get_access_token
}

When () {
  echo "$TESTNAME: When"
  mkdir -p $TESTSDIR/$TESTNAME

  # The mount command won't work properly when using dind!
  #  --mount type=bind,src=$PWD/$TESTSDIR/$TESTNAME,dst=/local --workdir=/local \
  # So, although this command demonstrates how we might normally run the command it is actually
  # the following command below that will allow us to grab the data
  docker run --rm --name wmed --net=host --mount type=bind,src=${PWD},dst=/local --workdir /local \
    -e NO_GIT=true \
    -e OAUTH2_CLIENT_ID=wmed \
    -e OAUTH2_CLIENT_SECRET=wmed \
    -e OAUTH2_TOKEN_URL=http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token \
    -e CLUSTER_HOST=localhost \
    -e MODEL_PATH=./files \
      $IMAGE_NAME:$IMAGE_REF deploy

  echo Sleep for a few seconds whilst docker container comes up ...
  sleep 5

  docker container stop wmed
  docker container rm wmed
}

Then () {
  echo "$TESTNAME: Then"

  expected_version=1

  search_process_definitions_by_bpmn_id_and_return_version "Process_ConnectorTest"
  assert_equals $expected_version, $actual_version

  search_process_definitions_by_bpmn_id_and_return_version "Process_Second"
  assert_equals $expected_version, $actual_version

  # TODO What other tests would be needed?
  #  1/ Change the process and check that its version number increments, or is this just
  #     testing the Camunda platform?
}

############################################################################
# So, the actual test is

_setup

  Given
  When
  Then

_teardown
