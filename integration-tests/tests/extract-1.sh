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

  create_project "Project"
#  add_collaborator demo@acme.com $project_id
  create_file Readme $project_id files/Readme.md markdown
  create_file process $project_id files/process.bpmn bpmn

  create_folder Folder1 $project_id
  create_file Readme $project_id files/Readme.md markdown $folder_id
  create_file process1 $project_id files/process.bpmn bpmn $folder_id
  create_file process2-wmedIgnore $project_id files/process.bpmn bpmn $folder_id

  create_folder Folder2.wmedIgnore $project_id
  create_file Readme $project_id files/Readme.md markdown $folder_id
  create_file process $project_id files/process.bpmn bpmn $folder_id
}

When () {
  echo "$TESTNAME: When"
  mkdir -p $TESTSDIR/$TESTNAME

  # The mount command won't work properly when using dind!
  #  --mount type=bind,src=$PWD/$TESTSDIR/$TESTNAME,dst=/local --workdir=/local \
  # So, although this command demonstrates how we might normally run the command it is actually
  # the following command below that will allow us to grab the data
  docker run --rm --net=host \
    -e NO_GIT=true \
    -e OAUTH2_CLIENT_ID=wmed -e OAUTH2_CLIENT_SECRET=wmed \
    -e OAUTH2_TOKEN_URL=http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token \
    -e CAMUNDA_WM_PROJECT="$project_id" \
    -e CAMUNDA_WM_HOST="localhost:8070" \
      $IMAGE_NAME:$IMAGE_REF extract

  # Unfortunately the command above doesn't allow us to grab the data - but doing it this way we can
  docker run -d $DOCKER_TTY_OPTS --name wmed --net=host -w /local \
    -e APP=/app -e NO_GIT=true \
    -e OAUTH2_CLIENT_ID=wmed -e OAUTH2_CLIENT_SECRET=wmed \
    -e OAUTH2_TOKEN_URL=http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token \
    -e CAMUNDA_WM_PROJECT="$project_id" \
    -e CAMUNDA_WM_HOST="localhost:8070" \
      --entrypoint /bin/sh $IMAGE_NAME:$IMAGE_REF

  echo Sleep for a few seconds whilst docker container comes up ...
  sleep 5

  docker exec $DOCKER_TTY_OPTS -w /local wmed /app/scripts/extractDeploy.sh extract
  docker container cp wmed:/local $TESTSDIR/$TESTNAME
  docker container stop wmed
  docker container rm wmed

  # Move the data where we want it
  mv $TESTSDIR/$TESTNAME/local/* $TESTSDIR/$TESTNAME
  rm -fr $TESTSDIR/$TESTNAME/local
}

Then () {
  echo "$TESTNAME: Then"
  # Then we have validate what we got back
  # Might be able to do this with a directory level diff

  if [ ! -f $TESTSDIR/$TESTNAME/config.yml ]; then
    exit 1
  else
    ext_project_id=`yq '.project.id' $TESTSDIR/$TESTNAME/config.yml`
    if [ "$ext_project_id" != "$project_id" ]; then
      exit 1
    fi
  fi
  if [ ! -f $TESTSDIR/$TESTNAME/Readme.md ]; then
    exit 1
  fi
  if [ ! -f $TESTSDIR/$TESTNAME/process.bpmn ]; then
    exit 1
  else
    xmllint --format $TESTSDIR/$TESTNAME/process.bpmn > $TESTSDIR/$TESTNAME/new-process.bpmn
    diff --ignore-all-space files/process.bpmn $TESTSDIR/$TESTNAME/new-process.bpmn
  fi

  if [ ! -d $TESTSDIR/$TESTNAME/Folder1 ]; then
    exit 1
  fi
  if [ ! -f $TESTSDIR/$TESTNAME/Folder1/Readme.md ]; then
    exit 1
  fi
  if [ ! -f $TESTSDIR/$TESTNAME/Folder1/process1.bpmn ]; then
    exit 1
  else
    xmllint --format $TESTSDIR/$TESTNAME/Folder1/process1.bpmn > $TESTSDIR/$TESTNAME/Folder1/new-process1.bpmn
    diff --ignore-all-space files/process.bpmn $TESTSDIR/$TESTNAME/Folder1/new-process1.bpmn
  fi
  if [ -f $TESTSDIR/$TESTNAME/Folder1/process2-wmedIgnore.bpmn ]; then
    exit 1
  fi

  if [ -f $TESTSDIR/$TESTNAME/Folder2.wmedIgnore ]; then
    exit 1
  fi
}

############################################################################
# So, the actual test is

_setup

  Given
  When
  Then

_teardown
