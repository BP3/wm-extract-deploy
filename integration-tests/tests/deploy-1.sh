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

  mkdir -p $TESTSDIR/$TESTNAME/deploy-files
  cp files/*.bpmn $TESTSDIR/$TESTNAME/deploy-files

  get_access_token
}

When () {
  echo "$TESTNAME: When"
  mkdir -p $TESTSDIR/$TESTNAME

  # The mount command won't work properly when using dind!
  #  --mount type=bind,src=$PWD/$TESTSDIR/$TESTNAME,dst=/local --workdir=/local \
  # So, although this command demonstrates how we might normally run the command it is actually
  # the following command below that will allow us to grab the data
#  docker run --rm --net=host --mount type=bind,src=${PWD},dst=/local --workdir /local \
#    -e NO_GIT=true \
#    -e OAUTH2_CLIENT_ID=$CLIENT_ID -e OAUTH2_CLIENT_SECRET=$CLIENT_SECRET \
#    -e OAUTH2_TOKEN_URL=http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token \
#    -e CLUSTER_HOST=localhost \
#    -e MODEL_PATH=./files \
#      $IMAGE_NAME:$IMAGE_REF deploy

  docker run -d $DOCKER_TTY_OPTS --name wmed --net=host -w /local \
    -e NO_GIT=true \
    -e CLUSTER_HOST=localhost \
    -e MODEL_PATH=./deploy-files \
      --entrypoint /bin/sh $IMAGE_NAME:$IMAGE_REF

  echo Sleep for a few seconds whilst docker container comes up ...
  sleep 5

  # Now we can copy into the container the files that we will want to deploy
  docker container cp $TESTSDIR/$TESTNAME/deploy-files wmed:/local
  docker exec $DOCKER_TTY_OPTS -w /local wmed /app/scripts/extractDeploy.sh deploy
  docker container stop wmed
  docker container rm wmed
}

Then () {
  echo "$TESTNAME: Then"

  expected_version=1
  get_access_token

  # Get the deployed version and key for the first process
  search_process_definitions_by_bpmn_id "Process_ConnectorTest"
  actual_version=$(echo $response | jq ".items[0].version")
  assert_equals $actual_version $expected_version
  process_1_key=$(echo $response | jq ".items[0].key")

  # Get the deployed version and key for the second process
  search_process_definitions_by_bpmn_id "Process_Second"
  actual_version=$(echo $response | jq ".items[0].version")
  assert_equals $actual_version $expected_version
  process_2_key=$(echo $response | jq ".items[0].key")

  # Now get back the deployed XML for the key, and check that it exactly matches what we deployed
  get_process_definition_xml_by_key "$process_1_key"
  echo $response >> $TESTSDIR/$TESTNAME/actual_process_1_xml.xml
  assert_xml_match $TESTSDIR/$TESTNAME/actual_process_1_xml.xml $TESTSDIR/$TESTNAME/deploy-files/process.bpmn

  get_process_definition_xml_by_key "$process_2_key"
  echo $response >> $TESTSDIR/$TESTNAME/actual_process_2_xml.xml
  assert_xml_match $TESTSDIR/$TESTNAME/actual_process_2_xml.xml $TESTSDIR/$TESTNAME/deploy-files/process2.bpmn
}

############################################################################
# So, the actual test is

_setup

  Given
  When
  Then

_teardown
