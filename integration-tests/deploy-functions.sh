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

# These probably aren't the right credentials for what we need here - since they are for Web Modeler!
# "demo/demo" credentials don't work either
ZEEBE_CLIENT_ID=zeebe
ZEEBE_CLIENT_SECRET=zecret
CLIENT_ID=$ZEEBE_CLIENT_ID
CLIENT_SECRET=$ZEEBE_CLIENT_SECRET
OPERATE_HOST=localhost
OPERATE_PORT=8081

# Load reusable core functions
. $TESTSDIR/core-functions.sh

search_process_definitions_by_bpmn_id () {
  get_access_token

  body="{\"filter\": {\"bpmnProcessId\": $1 }, \"size\": 1, \"sort\": [{\"field\": \"version\", \"order\": \"DESC\" } ] }"

  # TODO Switch to silent once this is all working
  response=$(curl -v -H "$APP_JSON_HDR" -H "Authorization: Bearer ${access_token}" \
        --data "$body" \
          -X GET http://$OPERATE_HOST:$OPERATE_PORT/v1/process-definitions/search)
}

get_process_definition_xml_by_key() {
  get_access_token

  # TODO Switch to silent once this is all working
  response=$(curl -v -H "$APP_JSON_HDR" -H "Authorization: Bearer ${access_token}" \
            -X GET http://$OPERATE_HOST:$OPERATE_PORT/v1/process-definitions/$1/xml)
}
