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

_setup () {
  # Make sure everything is clean before we start
  if [ -d $TESTSDIR/$TESTNAME ]; then
    rm -rf $TESTSDIR/$TESTNAME
  fi

  get_network_id
  echo "Network Id: $network_id"
}

_teardown () {
  :
  # Or we could leave everything behind so that it can be checked later
#  if [ -d $TESTSDIR/$TESTNAME ]; then
#    rm -rf $TESTSDIR/$TESTNAME
#  fi
}

Given () {
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
#  project_id=0caa33df-e339-44d5-8ea4-140138e68dfa
#  add_collaborator demo@acme.com $project_id
  create_file files/process.bpmn $project_id
#  file_id=53e55969-c144-4441-b44f-13eddce44c8b

#  create_folder Folder1 $project_id
#  create_file files/process1.bpmn $project_id $folder_id
#  create_file files/process2.wmedIgnore.bpmn $project_id $folder_id

#  create_folder Folder2.wmedIgnore $project_id
#  create_file files/process.bpmn $project_id $folder_id
#  create_file files/Readme.md $project_id $folder_id
}

When () {
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
  mkdir -p $TESTSDIR/$TESTNAME

  # The mount command won't work properly when using dind!
  #  --mount type=bind,src=$PWD/$TESTSDIR/$TESTNAME,dst=/local --workdir=/local \
  # So, although this command demonstrates how we might normally run the command it is actually
  # the following command below that will allow us to grab the data
  docker run --rm --net=host \
    -e NO_GIT=true \
    -e OAUTH2_CLIENT_ID=wmed -e OAUTH2_CLIENT_SECRET=wmed \
    -e OAUTH2_TOKEN_URL=http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token \
    -e CAMUNDA_WM_PROJECT="$project_id" \
    -e CAMUNDA_WM_HOST="localhost:8070" \
      bp3global/wm-extract-deploy extract

  # Unfortunately the command above doesn't allow us to grab the data - but doing it this way we can
  docker run -itd --name wmed --net=host -w /local \
    -e APP=/app -e NO_GIT=true \
    -e OAUTH2_CLIENT_ID=wmed -e OAUTH2_CLIENT_SECRET=wmed \
    -e OAUTH2_TOKEN_URL=http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token \
    -e CAMUNDA_WM_PROJECT="$project_id" \
    -e CAMUNDA_WM_HOST="localhost:8070" \
      --entrypoint /bin/sh bp3global/wm-extract-deploy
  docker exec -it -w /local wmed /app/scripts/extractDeploy.sh extract
  docker container cp wmed:/local $TESTSDIR/$TESTNAME
  docker container stop wmed
  docker container rm wmed

  # Move the data where we want it
  mv $TESTSDIR/$TESTNAME/local/* $TESTSDIR/$TESTNAME
  rm -fr $TESTSDIR/$TESTNAME/local
}

Then () {
  echo "$TESTNAME: Then"
  # Then we have validate what we got back
  # Might be able to do this with a directory level diff

  if [ -f $TESTSDIR/$TESTNAME/config.yml ]; then
    ext_project_id=`yq '.project.id' $TESTSDIR/$TESTNAME/config.yml`
#    if [ "$ext_project_id" != "$project_id" ]; then
#      exit 1
#    fi
  fi

  if [ ! -f $TESTSDIR/$TESTNAME/process.bpmn ]; then
    exit 1
#  else
#    xmllint --format $TESTSDIR/$TESTNAME/process.bpmn > $TESTSDIR/$TESTNAME/new-process.bpmn
#    diff --ignore-all-space $TESTSDIR/$TESTNAME/process.bpmn $TESTSDIR/$TESTNAME/new-process.bpmn
  fi
}

############################################################################
# So, the actual test is

# Scenario: WMED extracts files from project into a local directory

_setup

Given
When
Then

_teardown
