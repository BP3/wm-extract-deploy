#!/bin/sh -e

############################################################################
#
# Licensed Materials - Property of BP3
#
# Web Modeler Extract Deploy (WMED)
#
# Copyright © BP3 Global Inc. 2024. All Rights Reserved.
# This software is subject to copyright protection under
# the laws of the United States and other countries.
#
############################################################################
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

usage() {
  if [ -n "$1" ]; then
    echo "$1"
  fi

cat << EOF
Usage: extractDeploy.sh <MODE>

A CI/CD automation wrapper for interacting with assets between a Camunda 8 Web Modeler project, Zeebe cluster, and source control repositories.

Available Modes:
  extract            Extracts the assets from a web modeler project, and commits them to the repository
  deploy             Deploys the assets from the repository to the specified Zeebe cluster
  deploy templates   Deploys the Connector templates from the repository into Web Modeler

The configuration options for the commands are defined in environment variables as this is intended to run as part of a CI/CD pipeline.
See https://github.com/BP3/wm-extract-deploy for more details.
EOF

  if [ -n "$1" ]; then
    exit 1
  fi
}

mode="$1"
shift
case "${mode}" in
    extract)
      echo "mode = 'extract'"
      "${SCRIPT_DIR}"/extract.sh "$@"
      ;;
    deploy)
      if [ $# -gt 0 ] && [ "$1" = "templates" ]; then
          shift
          echo "mode = 'deploy templates'"
          "${SCRIPT_DIR}"/deployTemplates.sh "$@"
      else
        echo "mode = 'deploy'"
        "${SCRIPT_DIR}"/deploy.sh "$@"
      fi
      ;;
    help)
      usage
      ;;
    *)
      usage "Unknown mode: '${mode}'"
      ;;
esac
