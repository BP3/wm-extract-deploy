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

# This is very early days so really expect this to change/evolve a lot - but you have to start somewhere

APP_JSON_HDR="Content-Type: application/json"
CLIENT_ID=wmed
CLIENT_SECRET=wmed
OPERATE_HOST=localhost
OPERATE_PORT=8081

# Load reusable core functions
. $TESTSDIR/core-functions.sh

search_process_definitions_by_bpmn_id () {
  get_access_token

  body="{\"filter\": {\"bpmnProcessId\": $1 }, \"size\": 1, \"sort\": [{\"field\": \"version\", \"order\": \"DESC\" } ] }"

  response=$(curl \
        -s -H "$APP_JSON_HDR" -H "Authorization: Bearer ${access_token}" \
        --data "$body" \
          -X GET http://OPERATE_HOST:OPERATE_PORT/api/v1/process-definitions/search)
}