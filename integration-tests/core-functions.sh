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

# The repository root, for running WMED from this checkout (WMED_RUN=local)
WMED_REPO=`cd $TESTSDIR/.. && pwd`

# Usage: run_wmed <work dir> <mode> [args...] <<EOF
#          VAR=value
#          ...
#        EOF
# Runs WMED's extractDeploy.sh <mode> [args...] with <work dir> as its working directory, and the settings read from
# stdin (one VAR=value per line, values without spaces). Returns WMED's exit code, so call it with '|| rc=$?'.
#
#   WMED_RUN=image (the default, and what CI uses): runs WMED in the $IMAGE_NAME:$IMAGE_REF image. The work dir's
#     contents are copied into the container's /local before the run and copied back out afterwards.
#   WMED_RUN=local: runs the scripts from this checkout, with the 'python' on PATH (3.10 or later, with
#     requirements.txt installed, e.g. an activated virtualenv), as you rather than bp3user.
run_wmed () {
  wmed_dir=$1
  shift
  wmed_env=`mktemp`
  cat > "$wmed_env"

  wmed_rc=0
  if [ "${WMED_RUN:-image}" = "local" ]; then
    run_wmed_local "$wmed_dir" "$wmed_env" "$@" || wmed_rc=$?
  else
    run_wmed_image "$wmed_dir" "$wmed_env" "$@" || wmed_rc=$?
  fi

  rm -f "$wmed_env"
  return $wmed_rc
}

run_wmed_image () {
  image_dir=$1
  image_env=$2
  shift 2

  # The mount command won't work properly when using dind, so the files are copied in and out instead
  docker run -d $DOCKER_TTY_OPTS --name wmed --net=host -w /local --env-file "$image_env" \
    --entrypoint /bin/sh $IMAGE_NAME:$IMAGE_REF > /dev/null || return $?

  image_rc=0
  docker container cp "$image_dir/." wmed:/local > /dev/null || image_rc=$?
  if [ $image_rc -eq 0 ]; then
    docker exec $DOCKER_TTY_OPTS -w /local wmed /app/scripts/extractDeploy.sh "$@" < /dev/null || image_rc=$?
    docker container cp wmed:/local/. "$image_dir" > /dev/null || true
  fi

  docker container rm -f wmed > /dev/null || true
  return $image_rc
}

run_wmed_local () {
  local_dir=$1
  local_env=$2
  shift 2

  if ! python -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2> /dev/null; then
    echo "WMED_RUN=local needs 'python' 3.10 or later on PATH, with requirements.txt installed (e.g. an activated virtualenv)"
    return 1
  fi

  # The scripts expect the Python files next to them, as the Dockerfile arranges in the image
  local_app=`mktemp -d`
  ln -s "$WMED_REPO"/scripts/*.sh "$WMED_REPO"/python/*.py "$local_app"/

  local_rc=0
  (cd "$local_dir" && set -a && . "$local_env" && set +a && "$local_app"/extractDeploy.sh "$@" < /dev/null) \
    || local_rc=$?

  rm -rf "$local_app"
  return $local_rc
}

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

# Usage: assert_success <exit code> <description of the command>
# For commands whose exit code is captured with '|| rc=$?' so that clean-up can run before the check.
assert_success () {
  if [ "$1" != "0" ]; then
    echo "$2 failed (exit code $1)"
    exit 1
  fi
}

# Usage: assert_xml_match <actual file> <expected file>
# Formats the actual XML with xmllint, then compares it with the expected file, ignoring whitespace.
# Fails explicitly rather than relying on 'set -e'.
assert_xml_match () {
  if ! xmllint --format "$1" > "$1.format"; then
    echo "'$1' is not valid XML"
    exit 1
  fi
  if ! diff --ignore-all-space "$2" "$1.format"; then
    echo "XML in '$1' does not match '$2' (differences above)"
    exit 1
  fi
}
