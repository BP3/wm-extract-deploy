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
    -e OAUTH2_CLIENT_ID=$CLIENT_ID \
    -e OAUTH2_CLIENT_SECRET=$CLIENT_SECRET \
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

  # Get the deployed version and key for the first process
  search_process_definitions_by_bpmn_id "Process_ConnectorTest"
  assert_numeric_equals $expected_version, "$response" | jq ".items[0].version"
  process_1_key=$($response | jq ".items[0].key")

  # Get the deployed version and key for the second process
  search_process_definitions_by_bpmn_id "Process_Second"
  assert_numeric_equals $expected_version, "$response" | jq ".items[0].version"
  process_2_key=$($response | jq ".items[0].key")

  # Now get back the deployed XML for the key, and check that it exactly matches what we deployed
  get_process_definition_xml_by_key "$process_1_key"
  actual_process_1_xml=$response
  expected_process_1_xml=$(cat files/process.bpmn)
  assert_equals "$actual_process_1_xml" "$expected_process_1_xml"

  get_process_definition_xml_by_key "$process_2_key"
  actual_process_2_xml=$response
  expected_process_2_xml=$(cat files/process2.bpmn)
  assert_equals "$actual_process_2_xml" "$expected_process_2_xml"
}

############################################################################
# So, the actual test is

_setup

  Given
  When
  Then

_teardown
