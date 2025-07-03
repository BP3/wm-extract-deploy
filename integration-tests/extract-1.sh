#!/bin/sh -e

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

############################################################################
#
# This file is intended to provide the basis of a reusable template.
# The test itself consists of running the following functions
#
#     _setup
#
#     Given
#     When
#     Then
#
#     _teardown
#
# The function implementation will obviously change from file to file (test to test).
#
############################################################################

TESTNAME=`basename $0 .sh`

# Load reusable extract functions
. $TESTSDIR/extract-functions.sh

function _setup {
  get_network_id
  echo "Network Id: $network_id"
}

function _teardown {
  # Do nothing
  :
}

function Given {
  echo "$TESTNAME: Given"
  # 1.  Need a local version of what project will look like - maybe in a separate directory
  # 2.  Will first need to create/import project into Web Modeler

  # Just trying some stuff out. This probably needs to go into functions later
  # Assumes that we have already run 'docker-compose -f ../extract-compose.yaml up -d'

  get_access_token

  # Big picture is
  #
  #   Project
  #     Readme[.md]
  #     process[.bpmn]
  #     Folder1
  #       Readme[.md]
  #       process1[.bpmn]
  #       process2.wmedIgnore[.bpmn]
  #     Folder2.wmedIgnore
  #       Readme[.md]
  #       process[.bpmn]

  create_project "Project"
#  add_collaborator demo@acme.com $project_id
  create_file files/process.bpmn $project_id

#  create_folder Folder1 $project_id
#  create_file files/process1.bpmn $project_id $folder_id
#  create_file files/process2.wmedIgnore.bpmn $project_id $folder_id

#  create_folder Folder2.wmedIgnore $project_id
#  create_file files/process.bpmn $project_id $folder_id
#  create_file files/Readme.md $project_id $folder_id
}

function When {
  echo "$TESTNAME: When"
  # Extract command will look something a bit like
  #
  # docker run --rm --network "${CI_PROJECT_NAME}_camunda-platform"
  #   --mount type=bind,src=${PWD},dst=/local --workdir /local \
  #   -e NO_GIT=1
  #      -e OAUTH2_CLIENT_ID="<Client Id>" \
  #      -e OAUTH2_CLIENT_SECRET="<Client secret>" \
  #      -e OAUTH2_TOKEN_URL="<The OAuth2 Token URL>" \
  #      -e CAMUNDA_WM_PROJECT="<The WM project to extract from>" \
  #      -e CAMUNDA_WM_HOST="<Web Modeller hostname>" \
  #      #-e GIT_USERNAME="<Git Username>" \
  #      #-e GIT_USER_EMAIL="<Git Email address>" \
  #      #-e SKIP_CI="<Indicate (\"true\" | \"false\") if you want to run any pipelines or not on the commit>" \
  #      #-e CICD_PLATFORM="Indicate which SCM platform is being used, such as \"gitlab\", \"github\" or \"bitbucket\"" \
  #      #-e CICD_SERVER_HOST="<The host of the GIT server. Only needed if using GitLab>" \
  #      #-e CICD_ACCESS_TOKEN="<CI platform access token>" \
  #      #-e CICD_REPOSITORY_PATH="<The path of the repository>" \
  #         extract
  mkdir -p $PWD/$TESTSDIR/$TESTNAME

  docker run --rm --network $network_id \
    --mount type=bind,src=$PWD/$TESTSDIR/$TESTNAME,dst=/local --workdir=/local \
    -e NO_GIT=true \
    -e OAUTH2_CLIENT_ID=wmed -e OAUTH2_CLIENT_SECRET=wmed \
    -e OAUTH2_TOKEN_URL=http://keycloak:18080/auth/realms/camunda-platform/protocol/openid-connect/token \
    -e CAMUNDA_WM_PROJECT="13cffe71-8340-49e7-94c2-fa55adb5575c" \
    -e CAMUNDA_WM_HOST="web-modeler-webapp:8070" \
      bp3global/wm-extract-deploy extract

#mode = 'extract'
#Excluding paths with segments that match wmedIgnore
#Traceback (most recent call last):
#  File "/app/scripts/extract.py", line 75, in <module>
#    Extraction(args).main()
#    ~~~~~~~~~~~~~~~~~~~~~^^
#  File "/app/scripts/extract.py", line 58, in main
#    project_id = self.wm.get_project(args.project)["id"]
#                 ~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^
#  File "/app/scripts/web_modeler.py", line 214, in get_project
#    projects = self.find_project("id", project_ref)
#  File "/app/scripts/web_modeler.py", line 107, in find_project
#    raise RuntimeError("Find project failed:", response.status_code, response.text, response.headers["www-authenticate"])
#RuntimeError: ('Find project failed:', 401, '', 'Bearer error="invalid_token", error_description="An error occurred while attempting to decode the Jwt: The iss claim is not valid", error_uri="https://tools.ietf.org/html/rfc6750#section-3.1"')
}

function Then {
  echo "$TESTNAME: Then"
  # Then we have validate what we got back
  # Might be able to do this with a directory level diff
}

############################################################################
# So, the actual test is

# Scenario: WMED extracts files from project into a local directory

_setup

Given
When
Then

_teardown
