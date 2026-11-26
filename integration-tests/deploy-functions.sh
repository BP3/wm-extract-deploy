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

CLIENT_ID=zeebe
CLIENT_SECRET=zecret
OPERATE_HOST=localhost
OPERATE_PORT=8081
# Zeebe's Elasticsearch exporter writes a record for each deployment and each deployed form. On the 8.7 stack nothing
# else shows forms (Operate doesn't handle them, and Zeebe's /v2 query endpoints don't exist yet), so the tests read
# these records. They're the exporter's internal records, not a public API: move to the /v2 API with Camunda 8.8+.
ELASTIC_URL=http://localhost:9200

# Load reusable core functions
. $TESTSDIR/core-functions.sh

search_process_definitions_by_bpmn_id () {
  id=$1
  body="{\"filter\": {\"bpmnProcessId\": \"$id\" }, \"size\": 1, \"sort\": [{\"field\": \"version\", \"order\": \"DESC\" }] }"

  response=$(curl -s -H "$APP_JSON_HDR" -H "Authorization: Bearer ${access_token}" \
        --data "$body" \
          -X POST http://$OPERATE_HOST:$OPERATE_PORT/v1/process-definitions/search)
}

# Usage: wait_for_process_definition <bpmnProcessId> <version>
# Operate only shows a deployment once it has imported it from Zeebe (about 6 seconds after the deploy when tested),
# so keep searching until the latest version is the one expected, or fail after OPERATE_WAIT_SECONDS.
# Leaves the last search result in $response, as search_process_definitions_by_bpmn_id does.
wait_for_process_definition () {
  wait_id=$1
  wait_version=$2
  wait_limit=${OPERATE_WAIT_SECONDS:-60}
  waited=0

  while true; do
    search_process_definitions_by_bpmn_id "$wait_id"
    if [ "$(echo "$response" | jq '.items[0].version')" = "$wait_version" ]; then
      echo "Process '$wait_id' version $wait_version found in Operate after ${waited}s"
      return 0
    fi
    if [ $waited -ge $wait_limit ]; then
      echo "Process '$wait_id' version $wait_version not found in Operate after ${wait_limit}s. Last response: $response"
      exit 1
    fi
    sleep 2
    waited=$((waited + 2))
  done
}

get_process_definition_xml_by_key() {
  key=$1

  response=$(curl -s -H "$APP_JSON_HDR" -H "Authorization: Bearer ${access_token}" \
            -X GET http://$OPERATE_HOST:$OPERATE_PORT/v1/process-definitions/$key/xml)
}

search_decision_definitions_by_decision_id () {
  id=$1
  body="{\"filter\": {\"decisionId\": \"$id\" }, \"size\": 1, \"sort\": [{\"field\": \"version\", \"order\": \"DESC\" }] }"

  response=$(curl -s -H "$APP_JSON_HDR" -H "Authorization: Bearer ${access_token}" \
        --data "$body" \
          -X POST http://$OPERATE_HOST:$OPERATE_PORT/v1/decision-definitions/search)
}

# Usage: wait_for_decision_definition <decisionId> <version>
# As wait_for_process_definition, for a DMN decision. Leaves the last search result in $response.
wait_for_decision_definition () {
  wait_id=$1
  wait_version=$2
  wait_limit=${OPERATE_WAIT_SECONDS:-60}
  waited=0

  while true; do
    search_decision_definitions_by_decision_id "$wait_id"
    if [ "$(echo "$response" | jq '.items[0].version')" = "$wait_version" ]; then
      echo "Decision '$wait_id' version $wait_version found in Operate after ${waited}s"
      return 0
    fi
    if [ $waited -ge $wait_limit ]; then
      echo "Decision '$wait_id' version $wait_version not found in Operate after ${wait_limit}s. Last response: $response"
      exit 1
    fi
    sleep 2
    waited=$((waited + 2))
  done
}

# Usage: get_drd_xml_by_key <decisionRequirementsKey>
# The deployed DMN file (its decision requirements graph) as Operate returns it, in $response
get_drd_xml_by_key () {
  key=$1

  response=$(curl -s -H "$APP_JSON_HDR" -H "Authorization: Bearer ${access_token}" \
            -X GET http://$OPERATE_HOST:$OPERATE_PORT/v1/drd/$key/xml)
}

# Usage: search_forms_by_form_id <formId>
# The exporter's record for the latest deployed version of the form, in $response
search_forms_by_form_id () {
  id=$1
  body="{\"query\": {\"bool\": {\"filter\": [{\"term\": {\"intent\": \"CREATED\"}}, {\"term\": {\"value.formId\": \"$id\"}}]}}, \"size\": 1, \"sort\": [{\"value.version\": \"desc\"}] }"

  response=$(curl -s -H "$APP_JSON_HDR" --data "$body" -X POST "$ELASTIC_URL/zeebe-record_form_*/_search")
}

# Usage: wait_for_form <formId> <version>
# As wait_for_process_definition, for a form, which the exporter shows a few seconds after the deploy. Leaves the
# last search result in $response; the form's content is in .hits.hits[0]._source.value.resource, in base64.
wait_for_form () {
  wait_id=$1
  wait_version=$2
  wait_limit=${OPERATE_WAIT_SECONDS:-60}
  waited=0

  while true; do
    search_forms_by_form_id "$wait_id"
    if [ "$(echo "$response" | jq '.hits.hits[0]._source.value.version')" = "$wait_version" ]; then
      echo "Form '$wait_id' version $wait_version found in Elasticsearch after ${waited}s"
      return 0
    fi
    if [ $waited -ge $wait_limit ]; then
      echo "Form '$wait_id' version $wait_version not found in Elasticsearch after ${wait_limit}s. Last response: $response"
      exit 1
    fi
    sleep 2
    waited=$((waited + 2))
  done
}

# Usage: get_latest_deployment_with_process <bpmnProcessId>
# The exporter's record for the latest deployment that included the process, in $response. Its value lists what was
# deployed: processesMetadata, decisionsMetadata, decisionRequirementsMetadata and formMetadata, each with
# resourceName, version and duplicate.
get_latest_deployment_with_process () {
  id=$1
  body="{\"query\": {\"bool\": {\"filter\": [{\"term\": {\"intent\": \"CREATED\"}}, {\"term\": {\"value.processesMetadata.bpmnProcessId\": \"$id\"}}]}}, \"size\": 1, \"sort\": [{\"key\": \"desc\"}] }"

  response=$(curl -s -H "$APP_JSON_HDR" --data "$body" -X POST "$ELASTIC_URL/zeebe-record_deployment_*/_search")
}

# Usage: latest_deployment_key_with_process <bpmnProcessId>
# Prints the key of the latest deployment that included the process, or 0 if there is none. A test notes this before
# deploying and then waits for a newer deployment, so it can only pass on its own deployment, even on a stack that
# wasn't empty (test-runner.sh starts each test on an empty one).
latest_deployment_key_with_process () {
  get_latest_deployment_with_process "$1"
  echo "$response" | jq '.hits.hits[0]._source.key // 0'
}

# Usage: wait_for_deployment_with_process <bpmnProcessId> <key before the deploy>
# Waits until the exporter shows a deployment that included the process and is newer than the given key, so the checks
# are on this test's deployment, not an earlier one. Leaves its record in $response.
wait_for_deployment_with_process () {
  wait_id=$1
  wait_after=$2
  wait_limit=${OPERATE_WAIT_SECONDS:-60}
  waited=0

  while true; do
    get_latest_deployment_with_process "$wait_id"
    if [ "$(echo "$response" | jq --argjson after "$wait_after" '(.hits.hits[0]._source.key // 0) > $after')" = "true" ]; then
      echo "Deployment with process '$wait_id' found in Elasticsearch after ${waited}s"
      return 0
    fi
    if [ $waited -ge $wait_limit ]; then
      echo "No deployment with process '$wait_id' newer than key $wait_after after ${wait_limit}s. Last response: $response"
      exit 1
    fi
    sleep 2
    waited=$((waited + 2))
  done
}
