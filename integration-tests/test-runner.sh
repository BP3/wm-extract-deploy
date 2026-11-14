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

if [ "$TESTSDIR" = "" ]; then
  TESTSDIR=`dirname $0`
fi
IMAGE_NAME=ghcr.io/bp3/wm-extract-deploy
IMAGE_REF=$1
composeFile=$2

# Want to make sure that we have the image we are supposed to be working with
image=`docker images --format "{{.ID}} \t{{.Repository}} \t{{.Tag}}" --filter=reference="$IMAGE_NAME:$IMAGE_REF" | wc -l`
if [ $(( image )) -ne 1 ]; then
  echo "Image $IMAGE_NAME:$IMAGE_REF not found, so pull it from registry"
  if ! docker pull $IMAGE_NAME:$IMAGE_REF; then
    echo "Image $IMAGE_NAME:$IMAGE_REF not found in registry, so exit!"
    exit 1
  fi
else
  echo "Docker image $IMAGE_NAME:$IMAGE_REF found"
fi

testStatus='Success'
# Are we running as part of a pipeline
if [ ! -n "$CI" ]; then
  alias "docker-compose"='docker compose'
  docker_tty_opts=-i
else
  docker_tty_opts=-i
fi

# How long to wait for the compose stack's services to respond before giving up
STACK_WAIT_SECONDS=${STACK_WAIT_SECONDS:-300}
TOKEN_URL=http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token

# Usage: get_token <client id> <client secret>
# Prints an access token from Keycloak, and fails if there isn't one yet
get_token () {
  curl -s -X POST $TOKEN_URL \
    --data-urlencode "client_id=$1" --data-urlencode "client_secret=$2" \
    --data-urlencode 'grant_type=client_credentials' | jq -re '.access_token'
}

operate_ready () {
  token=`get_token zeebe zecret` || return 1
  curl -sf -H "Authorization: Bearer $token" -H "Content-Type: application/json" --data '{}' \
    -X POST http://localhost:8081/v1/process-definitions/search
}

web_modeler_ready () {
  token=`get_token wmed wmed` || return 1
  curl -sf -H "Authorization: Bearer $token" http://localhost:8070/api/v1/info
}

# Usage: wait_for <description> <command> [args...]
# Runs the command every 5 seconds until it succeeds, or fails after STACK_WAIT_SECONDS
wait_for () {
  description=$1
  shift
  waited=0
  until "$@" > /dev/null 2>&1; do
    if [ $waited -ge $STACK_WAIT_SECONDS ]; then
      echo "Timed out after ${STACK_WAIT_SECONDS}s waiting for $description"
      return 1
    fi
    sleep 5
    waited=$((waited + 5))
  done
  echo "$description is ready (after ${waited}s)"
}

# Usage: wait_for_stack <compose file>
# Waits until the services the tests use respond, rather than sleeping for a fixed time
wait_for_stack () {
  if [ "$1" = "deploy-compose.yaml" ]; then
    wait_for "Keycloak (zeebe client)" get_token zeebe zecret &&
    wait_for "Zeebe" curl -sf http://localhost:9600/actuator/health/readiness &&
    wait_for "Operate" operate_ready
  else
    wait_for "Keycloak (wmed client)" get_token wmed wmed &&
    wait_for "Web Modeler REST API" curl -sf http://localhost:8091/health/readiness &&
    wait_for "Web Modeler API" web_modeler_ready
  fi
}

#
# This function will run a single test. It runs the actual test in a new shell.
# Each test enables "set -e" itself, and we also pass -e here as a backstop for any test that forgets to.
# So if it fails for any reason then it will cause the shell to terminate and
# return back here where we can run 'docker-compose down' to tidy everything up
# Longer-term it probably makes sense to make this function accept an array of tests
# which can all be run in the same docker compose session
#

run_test () {
  docker-compose -f $1 up -d
  echo "Waiting for the compose stack to be ready (up to ${STACK_WAIT_SECONDS}s for each service) ..."
  if ! wait_for_stack $1; then
    echo "Test '$2' not run: the compose stack wasn't ready"
    testStatus='Failure'
    docker-compose -f $1 down
    return
  fi

  echo "Running test $2"

  TESTSDIR=$TESTSDIR DOCKER_TTY_OPTS=$docker_tty_opts /bin/sh -e -x $TESTSDIR/tests/$2 $IMAGE_REF

  rc=$?
  if [ $rc -ne 0 ]; then
    echo "Test '$2' completed with an error (exit code '$rc')"
    testStatus='Failure'
  else
    echo "Test '$2' completed successfully (exit code '$rc')"
  fi

  # Kind of want a "finally" section to execute this in - it always has to happen
  docker-compose -f $1 down
}

if [ $composeFile = "extract-compose.yaml" ]; then
  # A for loop rather than 'ls | while read': the piped loop runs in a subshell, so testStatus set by run_test was lost
  for tst in `'ls' -1S $TESTSDIR/tests/extract*.sh`; do
    next_tst=`basename $tst`
    run_test $composeFile $next_tst
  done

fi

if [ $composeFile = "deploy-compose.yaml" ]; then
  # A for loop rather than 'ls | while read': the piped loop runs in a subshell, so testStatus set by run_test was lost
  for tst in `'ls' -1S $TESTSDIR/tests/deploy*.sh`; do
    next_tst=`basename $tst`
    run_test $composeFile $next_tst
  done
fi

# See if ANY of the tests failed
if [ "$testStatus" = "Success" ]; then
  rc=0
else
  rc=1
fi

exit $rc
