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
