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
CURL_VERSION=7.85.0
WM_HOST=web-modeler-webapp
WM_PORT=8070

# Load reusable core functions
. $TESTSDIR/core-functions.sh

get_wm_restapi_status () {
  # Readiness of WM REST API
  # Responds with {"status":"UP"}
  wm_restapi_status=$(docker run --rm --network $network_id curlimages/curl:$CURL_VERSION \
      -s -H "$APP_JSON_HDR" http://web-modeler-restapi:8091/health/readiness \
      | jq '.status' | tr -d '"')
  echo "WM REST API: $wm_restapi_status"
}

get_wm_webapp_status () {
  # Readiness of WM WebApp
  # Responds with {"status":"READY","workers":[{"id":1,"state":"listening","pid":13}]}
  wm_webapp_status=$(docker run --rm --network $network_id curlimages/curl:$CURL_VERSION \
      -s -H "$APP_JSON_HDR" http://web-modeler-webapp:8071/health/readiness \
      | jq '.status' | tr -d '"')
  echo "WM WebApp: $wm_webapp_status"
}

get_access_token () {
  access_token=$(docker run --rm --net=host curlimages/curl:$CURL_VERSION \
    --location -s --request POST 'http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token' \
    --header 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "client_id=$CLIENT_ID" \
    --data-urlencode "client_secret=$CLIENT_SECRET" \
    --data-urlencode 'grant_type=client_credentials' | jq '.access_token' | tr -d '"')
}

get_wm_info () {
  wm_api_info=$(docker run --rm --network $network_id curlimages/curl:$CURL_VERSION \
    -s -H "$APP_JSON_HDR" -H "Authorization: Bearer ${access_token}" \
    http://$WM_HOST:$WM_PORT/api/v1/info)
  echo $wm_api_info
}

create_project () {
  echo "create_project:"
  echo "  name: $1"
  #   This API will create a project
  #     POST /api/v1/projects
  #     body: {
  #       "name": "string"
  #     }
  #

  body="{\"name\": \"$1\"}"

  get_access_token

  response=$(docker run --rm --network $network_id curlimages/curl:$CURL_VERSION \
      -s -H "$APP_JSON_HDR" -H "Authorization: Bearer ${access_token}" \
      --data "$body" \
        -X POST http://$WM_HOST:$WM_PORT/api/v1/projects)

#  echo $response

  project_name=$(echo $response | jq '.name' | tr -d '"')
  project_id=$(echo $response | jq '.id' | tr -d '"')
  echo $project_id
}

add_project_collaborator () {
  echo "add_project_collaborator:"
  echo "  email: $1"
  echo "  projectId: $2"
  #   This API will add a collaborator to a project
  #	PUT /api/v1/collaborators
  #	body: {
  #	  "email": "string",
  #	  "projectId": "string",
  #	  "role": "string"
  #	}
  #

  body="{\"email\":\"$1\", \"projectId\":\"$2\", \"role\":\"project_admin\"}"

  get_access_token

  response=$(docker run --rm --network $network_id curlimages/curl:$CURL_VERSION \
      -s -H "$APP_JSON_HDR" -H "Authorization: Bearer ${access_token}" \
      --data "$body" \
	-X PUT http://$WM_HOST:$WM_PORT/api/v1/collaborators)

  echo $response
}

create_folder () {
  echo "create_folder:"
  echo "  name: $1"
  echo "  projectId: $2"
  if [ $# -gt 2 ]; then
    echo "  parent: $3"
  fi
  #   This API will create a folder
  #     POST /api/v1/folders
  #     body: {
  #       "name": "string",
  #       "projectId": "string",
  #       "parentId": "string"
  #     }
  #

  if [ $# -gt 2 ]; then
    body="{\"name\":\"$1\", \"projectId\":\"$2\", \"parentId\":\"$3\"}"
  else
    body="{\"name\":\"$1\", \"projectId\":\"$2\"}"
  fi

  get_access_token

  response=$(docker run --rm --network $network_id curlimages/curl:$CURL_VERSION \
    -s -H "$APP_JSON_HDR" -H "Authorization: Bearer ${access_token}" \
    --data "$body" \
      -X POST http://$WM_HOST:$WM_PORT/api/v1/folders)

#  echo $response

  folder_name=$(echo $response | jq '.name' | tr -d '"')
  folder_id=$(echo $response | jq '.id' | tr -d '"')
  echo $folder_id
}

create_file () {
  echo "create_file:"
  echo "  file: $1"
  echo "  projectId: $2"
  echo "  file: $3"
  type "  type: $4"
  if [ $# -gt 2 ]; then
    echo "  folder: $5"
  fi
  #   This API will create a file
  #     POST /api/v1/files
  #     body: {
  #       "name": "string",
  #       "folderId": "string",
  #       "projectId": "string",
  #       "content": "string",
  #       "fileType": "string"
  #     }
  #

  name=`basename $1`

  # Works for .bpmn files, need something a bit different for .md files
  file_content=`sed -e 's|\"|\\\"|g' -e 's/$/\\n/g' $3 | tr -d '\n'`

  if [ $# -gt 4 ]; then
    body="{\"name\":\"$name\", \"folderId\":\"$5\", \"projectId\":\"$2\", \"content\":\"$file_content\", \"fileType\":\"$4\"}"
  else
    body="{\"name\":\"$name\", \"projectId\":\"$2\", \"content\":\"$file_content\", \"fileType\":\"$4\"}"
  fi

  get_access_token

  response=$(docker run --rm --network $network_id curlimages/curl:$CURL_VERSION \
    -s -H "$APP_JSON_HDR" -H "Authorization: Bearer ${access_token}" \
    --data "$body" \
      -X POST http://$WM_HOST:$WM_PORT/api/v1/files)

  echo $response

  file_name=$(echo $response | jq '.name' | tr -d '"')
  file_id=$(echo $response | jq '.id' | tr -d '"')
  echo $file_id
}
