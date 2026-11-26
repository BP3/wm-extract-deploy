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
# What deploying the same models again does to their versions (#100). WMED deploys every model in one deployment,
# and Zeebe checks for duplicates across the whole deployment:
#
#   - the same set again creates no new versions: the deployment is marked as a duplicate
#   - a change to one model gives every model in the set a new version, including the unchanged ones
#
# The changed-only deploy mode planned in docs/direction.md will change the second on purpose, so this test records
# today's behaviour for it to be compared with.
#
# The test expects version numbers from an empty stack, which test-runner.sh gives each test (#117).
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

# One of each resource type: process Process_ResourceTypes, decision Decision_Discount, forms customer-details and
# order-details
MODELS=files/resource-types
PROCESS_ID=Process_ResourceTypes

_setup () {
  # Make sure everything is clean before we start
  if [ -d $TESTSDIR/$TESTNAME ]; then
    rm -rf $TESTSDIR/$TESTNAME
  fi
}

_teardown () {
  :
}

# Usage: deploy_models <description>
# Runs WMED's deploy on the test's models and waits for the deployment it made. Leaves the deployment's exporter
# record in $response.
deploy_models () {
  echo "$TESTNAME: deploy $1"
  deployment_before=$(latest_deployment_key_with_process "$PROCESS_ID")

  rc=0
  run_wmed $TESTSDIR/$TESTNAME deploy <<EOF || rc=$?
NO_GIT=true
CLUSTER_HOST=localhost
MODEL_PATH=./deploy-files
LOG_LEVEL=DEBUG
EOF
  assert_success "$rc" "WMED deploy $1"

  wait_for_deployment_with_process "$PROCESS_ID" "$deployment_before"
}

# Usage: deployed_versions
# Each model in the deployment record in $response, as <id>:<version>, sorted and space separated
deployed_versions () {
  echo "$response" | jq -r '[.hits.hits[0]._source.value |
    (.processesMetadata[] | "\(.bpmnProcessId):\(.version)"),
    (.decisionsMetadata[] | "\(.decisionId):\(.version)"),
    (.formMetadata[] | "\(.formId):\(.version)")] | sort | join(" ")'
}

# Usage: duplicate_flags
# The distinct duplicate flags of the models in the deployment record in $response: "true" if Zeebe treated every
# model as a duplicate, "false" if none
duplicate_flags () {
  echo "$response" | jq -r '[.hits.hits[0]._source.value |
    (.processesMetadata[], .decisionsMetadata[], .formMetadata[]) | .duplicate] | unique | join(" ")'
}

Given () {
  echo "$TESTNAME: Given"

  mkdir -p $TESTSDIR/$TESTNAME/deploy-files
  cp -R $MODELS/. $TESTSDIR/$TESTNAME/deploy-files

  get_access_token

  # The models deployed once
  deploy_models "of the models"
  assert_equals "$(deployed_versions)" \
    "Decision_Discount:1 Process_ResourceTypes:1 customer-details:1 order-details:1"
  assert_equals "$(duplicate_flags)" "false"
}

When () {
  echo "$TESTNAME: When"

  # The same models again
  deploy_models "of the same models again"
  same_again_versions=$(deployed_versions)
  same_again_duplicates=$(duplicate_flags)

  # Then the models with a change to the process only: its name
  sed 's/name="Resource types"/name="Resource types, changed"/' $MODELS/approval.bpmn \
    > $TESTSDIR/$TESTNAME/deploy-files/approval.bpmn
  if cmp -s $MODELS/approval.bpmn $TESTSDIR/$TESTNAME/deploy-files/approval.bpmn; then
    echo "The process wasn't changed, so the test can't check a change"
    exit 1
  fi
  deploy_models "with the process changed"
  changed_versions=$(deployed_versions)
  changed_duplicates=$(duplicate_flags)
}

Then () {
  echo "$TESTNAME: Then"

  # The same models again: a duplicate deployment, with no new versions
  assert_equals "$same_again_versions" \
    "Decision_Discount:1 Process_ResourceTypes:1 customer-details:1 order-details:1"
  assert_equals "$same_again_duplicates" "true"

  # One model changed: every model gets a new version, including the decision and forms that didn't change.
  # The changed-only deploy mode will change this on purpose (docs/direction.md)
  assert_equals "$changed_versions" \
    "Decision_Discount:2 Process_ResourceTypes:2 customer-details:2 order-details:2"
  assert_equals "$changed_duplicates" "false"

  # The process's new version is the changed file
  get_access_token
  wait_for_process_definition "$PROCESS_ID" 2
  process_key=$(echo $response | jq ".items[0].key")
  get_process_definition_xml_by_key "$process_key"
  # printf rather than an unquoted echo, so the XML is written exactly as Operate returned it
  printf "%s\n" "$response" > $TESTSDIR/$TESTNAME/actual_process.bpmn
  assert_xml_match $TESTSDIR/$TESTNAME/actual_process.bpmn $TESTSDIR/$TESTNAME/deploy-files/approval.bpmn
}

############################################################################
# So, the actual test is

_setup

  Given
  When
  Then

_teardown
