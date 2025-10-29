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
  mkdir -p $TESTSDIR/$TESTNAME
  cp files/*.bpmn $TESTSDIR/$TESTNAME

  get_access_token
}

When () {
  echo "$TESTNAME: When"
  mkdir -p $TESTSDIR/$TESTNAME

  # The mount command won't work properly when using dind, so we have to do it this way to allow us to grab
  # Also it allows us to call the extractDeploy.sh script interactively otherwise the container will run and complete
  # Don't set the MODEL_PATH so it defaults to the root of the repository (i.e. '.')
  docker run -d $DOCKER_TTY_OPTS --name wmed --net=host -w /local \
    -e NO_GIT=true \
    -e CLUSTER_HOST=localhost \
      --entrypoint /bin/sh $IMAGE_NAME:$IMAGE_REF

  echo Sleep for a few seconds whilst docker container comes up ...
  sleep 5

  # Now we can copy into the container the files to the root of the repository which is the default location
  # of MODEL_PATH that is set by the 'deploy.sh' script, which is where we will deploy the process models from
  docker container cp $TESTSDIR/$TESTNAME wmed:/local
  docker exec $DOCKER_TTY_OPTS -w /local wmed /app/scripts/extractDeploy.sh deploy < /dev/null
  docker container stop wmed
  docker container rm wmed
}

Then () {
  echo "$TESTNAME: Then"

  expected_version=1
  get_access_token

  # Get the deployed version and key for the process
  search_process_definitions_by_bpmn_id "Process_ConnectorTest"
  actual_version=$(echo $response | jq ".items[0].version")
  assert_equals $actual_version $expected_version
  process_key=$(echo $response | jq ".items[0].key")

  # Now get back the deployed XML for the key, and check that it exactly matches what we deployed
  get_process_definition_xml_by_key "$process_key"
  echo $response >> $TESTSDIR/$TESTNAME/actual_process_xml.xml
  assert_xml_match $TESTSDIR/$TESTNAME/actual_process_xml.xml $TESTSDIR/$TESTNAME/process.bpmn
}

############################################################################
# So, the actual test is

_setup

  Given
  When
  Then

_teardown
