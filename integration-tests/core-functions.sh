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

get_network_id () {
  network_id=`docker network ls --format "{{.Name}}" | grep camunda-platform`
}

get_access_token () {
  access_token=$(curl \
    --location -s --request POST 'http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token' \
    --header 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "client_id=$CLIENT_ID" \
    --data-urlencode "client_secret=$CLIENT_SECRET" \
    --data-urlencode 'grant_type=client_credentials' | jq '.access_token' | tr -d '"')
}

# Usage: assert_equals <actual> <expected>
# Compares as strings, and treats an empty or "null" actual value (e.g. from jq when nothing was found) as a failure.
# Quote the arguments when calling it, otherwise an empty value disappears and the arguments shift.
assert_equals() {
  if [ -z "$1" ] || [ "$1" = "null" ]; then
    echo "Expected '$2' but got no value ('$1')"
    exit 1
  fi
  if [ "$1" != "$2" ]; then
    echo "Expected '$2' but got '$1'"
    exit 1
  fi
}

assert_xml_match () {
  xmllint --format $1 > $1.format
  diff --ignore-all-space $2 $1.format
}
