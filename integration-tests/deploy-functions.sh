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

get_process_definition_xml_by_key() {
  key=$1

  response=$(curl -s -H "$APP_JSON_HDR" -H "Authorization: Bearer ${access_token}" \
            -X GET http://$OPERATE_HOST:$OPERATE_PORT/v1/process-definitions/$key/xml)
}
