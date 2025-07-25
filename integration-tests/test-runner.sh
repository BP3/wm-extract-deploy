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
IMAGE_NAME=bp3/wm-extract-deploy
IMAGE_REF=$1
composeFile=$2

# Want to make sure that we have the image we are supposed to be working with
image=`docker images --format "{{.ID}} \t{{.Repository}} \t{{.Tag}}" --filter=reference="ghcr.io/$IMAGE_NAME:$IMAGE_REF" | wc -l`
if [ $(( image )) -ne 1 ]; then
  echo "Image $IMAGE_NAME:$IMAGE_REF not found, so pull it from registry"
  docker pull ghcr.io/$IMAGE_NAME:$IMAGE_REF
  if [ $? -ge 0 ]; then
    echo "Image $IMAGE_NAME:$IMAGE_REF not found in registry, so exit\!"
    exit 1
  fi
else
  echo "Docker image $IMAGE_NAME:$IMAGE_REF found"
fi

status='Success'
# Are we running as part of a pipeline
if [ ! -n "$CI" ]; then
  alias "docker-compose"='docker compose'
  docker_tty_opts=-i
else
  docker_tty_opts=-i
fi

#
# This function will run a single test. It runs the actual test in a new shell.
# Since the test has "set -e" enabled then if it fails for any reason then it will cause the shell to terminate and
# return back here where we can run 'docker-compose down' to tidy everything up
# Longer-term it probably makes sense to make this function accept an array of tests
# which can all be run in the same docker compose session
#

run_test () {
  docker-compose -f $1 up -d
  echo Sleeping whilst compose stack comes up properly ...
  sleep 15

  echo "Running test $2"

  TESTSDIR=$TESTSDIR DOCKER_TTY_OPTS=$docker_tty_opts /bin/sh -x $TESTSDIR/tests/$2 $IMAGE_REF

  rc=$?
  if [ $rc -ne 0 ]; then
    echo "Test $1 completed with an error"
    status='Failure'
  else
    echo "Test completed successfully"
  fi

  # Kind of want a "finally" section to execute this in - it always has to happen
  docker-compose -f $1 down
}

'ls' -1S $TESTSDIR/tests/extract*.sh | while read tst; do
  tst=`basename $tst`
  run_test $composeFile $tst
done

# See if ANY of the tests failed
if [ "$status" = "Success" ]; then
  rc=0
else
  rc=1
fi

exit $rc
