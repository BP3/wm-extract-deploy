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
  # 1.  Need a local version of project - maybe in a separate directory

  mkdir -p $TESTSDIR/$TESTNAME

  cp files/Readme.md $TESTSDIR/$TESTNAME
  cp files/process.bpmn $TESTSDIR/$TESTNAME
}

When () {
  echo "$TESTNAME: When"

  # This is broadly how we expect to use the deploy command - but it won't work properly when using dind!
  #  --mount type=bind,src=$PWD/$TESTSDIR/$TESTNAME,dst=/local --workdir=/local \
  # So, although this command demonstrates how we might normally run the command it is actually
  # the following command below that will allow us to deploy the data
#  docker run --rm --net=host \
#    -e NO_GIT=true \
#    -e OAUTH2_CLIENT_ID=wmed -e OAUTH2_CLIENT_SECRET=wmed \
#    -e OAUTH2_TOKEN_URL=http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token \
#    -e ZEEBE_CLUSTER_HOST=localhost -e ZEEBE_CLUSTER_PORT=26500 \
#      $IMAGE_NAME:$IMAGE_REF deploy

  # Unfortunately the command above doesn't allow us to grab the data - but doing it this way we can
  docker run -d $DOCKER_TTY_OPTS --name wmed --net=host -w /local \
    -e APP=/app -e NO_GIT=true \
    -e ZEEBE_CLUSTER_HOST=localhost -e ZEEBE_CLUSTER_PORT=26500 \
      --entrypoint /bin/sh $IMAGE_NAME:$IMAGE_REF

  echo Sleep for a few seconds whilst docker container comes up ...
  sleep 5

  # Will have to copy the artifacts that need to be deployed into the container
  docker container cp $TESTSDIR/$TESTNAME wmed:/local
  docker exec $DOCKER_TTY_OPTS -w /local wmed /app/scripts/extractDeploy.sh deploy
  docker container stop wmed
  docker container rm wmed
}

Then () {
  echo "$TESTNAME: Then"

}

############################################################################
# So, the actual test is

_setup

  Given
  When
  Then

_teardown
