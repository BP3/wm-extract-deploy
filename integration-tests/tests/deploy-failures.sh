#!/bin/sh

############################################################################
#
# Licensed Materials - Property of BP3
#
# Web Modeler Extract Deploy (WMED)
#
# Copyright © BP3 Global Inc. 2026. All Rights Reserved.
# This software is subject to copyright protection under
# the laws of the United States and other countries.
#
############################################################################
#
# How deploy fails (#100):
#
#   - A set with an invalid model: Zeebe rejects the whole deployment, so nothing in it is deployed, not even the
#     valid models. WMED logs Zeebe's error, which names the file, and exits with 3.
#   - A MODEL_PATH with nothing to deploy: WMED logs a warning and exits with 0. The warning is at WARNING level and
#     LOG_LEVEL defaults to ERROR, so by default WMED says nothing at all.
#   - A MODEL_PATH that doesn't exist: WMED says so and exits with 2.
#
# The test follows the template of the other tests:
#
#     _setup
#
#     Given
#     When
#     Then
#
#     _teardown
#
############################################################################

TESTNAME=`basename $0 .sh`
IMAGE_NAME=ghcr.io/bp3/wm-extract-deploy
IMAGE_REF=$1

# Stop at the first failing command
set -e

# Load reusable deploy functions
. $TESTSDIR/deploy-functions.sh

MODELS=files/invalid-model
WORK=$TESTSDIR/$TESTNAME/work

_setup () {
  # Make sure everything is clean before we start
  if [ -d $TESTSDIR/$TESTNAME ]; then
    rm -rf $TESTSDIR/$TESTNAME
  fi
}

_teardown () {
  :
}

# Usage: deploy_from <model path> <log name>
# Runs WMED deploy in the work folder with MODEL_PATH set to the given path, writing its output to <log name>.log in
# the test's folder and showing it. Sets rc to WMED's exit code and log to the log file. The logs stay out of the work
# folder, as in image mode run_wmed copies the container's copy of the work folder back over it after the run.
deploy_from () {
  log=$TESTSDIR/$TESTNAME/$2.log
  rc=0
  run_wmed $WORK deploy > "$log" 2>&1 <<EOF || rc=$?
NO_GIT=true
CLUSTER_HOST=localhost
MODEL_PATH=$1
LOG_LEVEL=WARNING
EOF
  cat "$log"
  echo "WMED exited with $rc"
}

# Usage: assert_logged <text> <description>
# Fails the test unless the last deploy_from's log contains the text
assert_logged () {
  if ! grep -q -F -- "$1" "$log"; then
    echo "Expected $2 in WMED's output: $1"
    exit 1
  fi
}

Given () {
  echo "$TESTNAME: Given"

  #   invalid-set/good.bpmn     a valid process, Process_Good
  #   invalid-set/broken.bpmn   a service task without a job type, which Zeebe rejects
  #   valid-only/good.bpmn      the same valid process on its own
  #   nothing-to-deploy/        only a file that isn't a model
  mkdir -p $WORK/invalid-set $WORK/valid-only $WORK/nothing-to-deploy
  cp $MODELS/good.bpmn $MODELS/broken.bpmn $WORK/invalid-set
  cp $MODELS/good.bpmn $WORK/valid-only
  echo "Not a model" > $WORK/nothing-to-deploy/notes.md

  get_access_token
}

When () {
  echo "$TESTNAME: When"

  deploy_from ./invalid-set invalid-set
  invalid_rc=$rc
  invalid_log=$log

  # Then the valid model on its own. If any of the rejected deployment had gone in, this would be a duplicate of it
  deploy_from ./valid-only valid-only
  valid_rc=$rc

  deploy_from ./nothing-to-deploy nothing-to-deploy
  nothing_rc=$rc
  nothing_log=$log

  deploy_from ./does-not-exist does-not-exist
  missing_rc=$rc
  missing_log=$log
}

Then () {
  echo "$TESTNAME: Then"

  # The invalid set: rejected with exit code 3, and Zeebe's error names the invalid file
  assert_equals "$invalid_rc" "3"
  log=$invalid_log
  assert_logged "'broken.bpmn'" "Zeebe's error naming the invalid file"

  # Nothing from the rejected set was deployed: the valid model's own deployment is the only one with Process_Good,
  # and it isn't a duplicate. The stack starts empty, so an earlier run can't have deployed it
  assert_success "$valid_rc" "WMED deploy of the valid model on its own"
  wait_for_deployment_with_process "Process_Good" 0
  deployments=$(echo "$response" | jq '.hits.total.value')
  assert_equals "$deployments" "1"
  duplicate=$(echo "$response" | jq -r '.hits.hits[0]._source.value.processesMetadata[0].duplicate')
  assert_equals "$duplicate" "false"
  wait_for_process_definition "Process_Good" 1

  # Nothing to deploy: a warning, and success
  assert_success "$nothing_rc" "WMED deploy with nothing to deploy"
  log=$nothing_log
  assert_logged "Didn't find any files to deploy" "the warning that there was nothing to deploy"

  # A MODEL_PATH that doesn't exist: exit code 2
  assert_equals "$missing_rc" "2"
  log=$missing_log
  assert_logged "does not exist" "the error that MODEL_PATH doesn't exist"
}

############################################################################
# So, the actual test is

_setup

  Given
  When
  Then

_teardown
