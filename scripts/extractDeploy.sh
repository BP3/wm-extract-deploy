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
