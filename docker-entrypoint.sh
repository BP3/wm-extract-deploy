#!/bin/bash

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

# This script has to handle being called locally or from a GitLab CI / CD pipeline.
# The requirements are stipulated here (although provides no real examples):
#   https://docs.gitlab.com/runner/executors/docker.html#configure-a-docker-entrypoint
# Further more, this link shows an example based on those requirements which this script is based upon:
#   https://stackoverflow.com/questions/70401876/gitlab-runner-doesnt-run-entrypoint-scripts-in-dockerfile

# The CI variable is a boolean that is set to true if we are running in a CI/CD environment.
# If we are then we execute a bash shell and the script block commands are piped in
if [[ -n "$CI" ]]; then
    exec /bin/bash
# Otherwise we are running outside CI/CD, so execute the command line wrapper script directly
else
    exec $SCRIPT_DIR/extractDeploy.sh "$@"
fi
