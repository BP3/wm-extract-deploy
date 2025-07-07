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

status='Success'
# Are we running as part of a pipeline
if [ ! -n "$CI" ]; then
  alias "docker-compose"='docker compose'
  docker_tty_opts=-i
else
  docker_tty_opts=-i
fi

# Test if the following are installed - they all are except xmllint
which curl jq yq xmllint

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

  TESTSDIR=$TESTSDIR DOCKER_TTY_OPTS=$docker_tty_opts /bin/sh -x $TESTSDIR/tests/$2

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
  run_test extract-compose.yaml $tst
done

# See if ANY of the tests failed
if [ "$status" = "Success" ]; then
  rc=0
else
  rc=1
fi

exit $rc
