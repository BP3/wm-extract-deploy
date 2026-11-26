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

############################################################################
#
# Deploy finds every resource type it supports (.bpmn, .dmn and .form) under MODEL_PATH, in subfolders too, leaves
# other files out, and deploys them together in one deployment, each with content that matches its file (#100).
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

MODELS=files/resource-types

_setup () {
  # Make sure everything is clean before we start
  if [ -d $TESTSDIR/$TESTNAME ]; then
    rm -rf $TESTSDIR/$TESTNAME
  fi
}

_teardown () {
  :
}

Given () {
  echo "$TESTNAME: Given"

  # One of each resource type, some in subfolders:
  #   approval.bpmn                 process Process_ResourceTypes
  #   rules/discount.dmn            decision Decision_Discount
  #   forms/customer/details.form   form customer-details
  #   forms/order/details.form      form order-details (the same file name in another folder)
  #   notes.md                      not a model. Zeebe rejects a whole deployment with an unknown resource type, so a
  #                                 successful deploy shows WMED left it out
  mkdir -p $TESTSDIR/$TESTNAME/deploy-files
  cp -R $MODELS/. $TESTSDIR/$TESTNAME/deploy-files

  # The stack keeps its data between runs, so note the latest deployment of these models before deploying, and check
  # only a newer one
  deployment_before=$(latest_deployment_key_with_process "Process_ResourceTypes")
  echo "Latest deployment with these models before the deploy: $deployment_before"

  get_access_token
}

When () {
  echo "$TESTNAME: When"

  # Run WMED in the image, or from this checkout with WMED_RUN=local, capturing its exit code
  rc=0
  run_wmed $TESTSDIR/$TESTNAME deploy <<EOF || rc=$?
NO_GIT=true
CLUSTER_HOST=localhost
MODEL_PATH=./deploy-files
LOG_LEVEL=DEBUG
EOF
  assert_success "$rc" "WMED deploy"
}

Then () {
  echo "$TESTNAME: Then"

  expected_version=1
  get_access_token

  # This test's deployment: all four models went in one deployment, and nothing else did
  wait_for_deployment_with_process "Process_ResourceTypes" "$deployment_before"
  deployed=$(echo "$response" | jq -r '[.hits.hits[0]._source.value |
    (.processesMetadata[], .decisionRequirementsMetadata[], .formMetadata[]) | .resourceName] | sort | join(" ")')
  assert_equals "$deployed" "approval.bpmn details.form details.form discount.dmn"
  # On a stack with data from an earlier run, the same content is a duplicate of version 1, not a new version
  versions=$(echo "$response" | jq -r '[.hits.hits[0]._source.value |
    (.processesMetadata[].version, .decisionsMetadata[].version, .formMetadata[].version)] | unique | join(" ")')
  assert_equals "$versions" "$expected_version"

  # The process, with the XML that was deployed
  wait_for_process_definition "Process_ResourceTypes" "$expected_version"
  process_key=$(echo $response | jq ".items[0].key")
  get_process_definition_xml_by_key "$process_key"
  # printf rather than an unquoted echo, so the XML is written exactly as Operate returned it
  printf "%s\n" "$response" > $TESTSDIR/$TESTNAME/actual_process.bpmn
  assert_xml_match $TESTSDIR/$TESTNAME/actual_process.bpmn $MODELS/approval.bpmn

  # The decision, from a subfolder, with the DMN that was deployed
  wait_for_decision_definition "Decision_Discount" "$expected_version"
  drd_key=$(echo $response | jq ".items[0].decisionRequirementsKey")
  get_drd_xml_by_key "$drd_key"
  printf "%s\n" "$response" > $TESTSDIR/$TESTNAME/actual_decision.dmn
  assert_xml_match $TESTSDIR/$TESTNAME/actual_decision.dmn $MODELS/rules/discount.dmn

  # Both forms, from two folders with the same file name, each with exactly the content of its file
  for form in customer order; do
    wait_for_form "$form-details" "$expected_version"
    echo "$response" | jq -r ".hits.hits[0]._source.value.resource" | base64 -d > $TESTSDIR/$TESTNAME/actual_$form.form
    assert_same_file $TESTSDIR/$TESTNAME/actual_$form.form $MODELS/forms/$form/details.form
  done
}

############################################################################
# So, the actual test is

_setup

  Given
  When
  Then

_teardown
