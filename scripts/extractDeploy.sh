#!/bin/bash

mode_extract=0
mode_deploy=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        extract)
          mode_extract=1
            ;;
        deploy)
          mode_deploy=1
            ;;
        *)
          echo "Unknown mode: '$1'"
          exit 1
            ;;
    esac
    shift
done

# If the mode has not been passed in as a service parameter, then see if it has been set as an environment variable
# If it is set as an environment variable, passing in as a service parameter will take precedence anyway
if [ $mode_extract == 0 ] && [ $mode_deploy == 0 ]; then
  if [ "$MODE" == "extract" ]; then
    mode_extract=1
  elif [ "$MODE" == "deploy" ]; then
    mode_deploy=1
  # If we get to here, then it has not been set by either method
  else
    echo "The MODE env var or service parameter has not been set to 'extract' or 'deploy'"
    exit 1
  fi
fi

if [ $mode_extract == 1 ]; then
  echo "mode = 'extract'"
#  checkRequiredEnvVar CAMUNDA_WM_CLIENT_ID          "$CAMUNDA_WM_CLIENT_ID"
#  checkRequiredEnvVar CAMUNDA_WM_CLIENT_SECRET      "$CAMUNDA_WM_CLIENT_SECRET"
#  checkRequiredEnvVar CICD_PLATFORM                 "$CICD_PLATFORM"
#  checkRequiredEnvVar CICD_ACCESS_TOKEN             "$CICD_ACCESS_TOKEN"
#  checkRequiredEnvVar CICD_REPOSITORY_PATH          "$CICD_REPOSITORY_PATH"
#  checkRequiredEnvVar GIT_USERNAME                  "$GIT_USERNAME"
#  checkRequiredEnvVar GIT_USER_EMAIL                "$GIT_USER_EMAIL"

  $SCRIPT_DIR/extract.sh
fi

if [ $mode_deploy == 1 ]; then
  echo "mode = 'deploy'"
#  checkRequiredEnvVar ZEEBE_CLIENT_ID               "$ZEEBE_CLIENT_ID"
#  checkRequiredEnvVar ZEEBE_CLIENT_SECRET           "$ZEEBE_CLIENT_SECRET"
#  checkRequiredEnvVar CAMUNDA_CLUSTER_ID            "$CAMUNDA_CLUSTER_ID"
#  checkRequiredEnvVar CAMUNDA_CLUSTER_REGION        "$CAMUNDA_CLUSTER_REGION"
#  checkRequiredEnvVar PROJECT_TAG                   "$PROJECT_TAG"

  $SCRIPT_DIR/deploy.sh
fi
