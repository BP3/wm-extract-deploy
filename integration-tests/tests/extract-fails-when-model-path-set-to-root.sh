#!/bin/sh

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

# Stop at the first failing command
set -e

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

  get_access_token

  # Give us something to extract although we are not testing this specifically
  # as that test case is handled in other tests
  create_project "Project"
  create_file process $project_id files/process.bpmn bpmn
}

When () {
  echo "$TESTNAME: When"
  mkdir -p $TESTSDIR/$TESTNAME

  # Set MODEL_PATH to the root of the file system, which WMED can't write to, so the extract should fail.
  # The exit code is captured rather than letting 'set -e' end the test, and checked in Then
  rc=0
  run_wmed $TESTSDIR/$TESTNAME extract <<EOF || rc=$?
NO_GIT=true
MODEL_PATH=/
OAUTH2_CLIENT_ID=wmed
OAUTH2_CLIENT_SECRET=wmed
OAUTH2_TOKEN_URL=http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token
CAMUNDA_WM_PROJECT=$project_id
CAMUNDA_WM_HOST=localhost:8070
LOG_LEVEL=DEBUG
EOF
}

Then () {
  echo "$TESTNAME: Then"

  # The extract should have failed, because it can't write to the root of the file system. In the image we should
  # see "PermissionError: [Errno 13] Permission denied: '//process.bpmn'" in the output; locally the error may differ
  # (on macOS the root is read-only)
  assert_equals "$rc" 1
}

############################################################################
# So, the actual test is

_setup

  Given
  When
  Then

_teardown
