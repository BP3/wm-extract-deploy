#!/bin/bash

# This script has to handle being called locally or from a GitLab CI / CD pipeline.
# The requirements are stipulated here (although provides no real examples):
#   https://docs.gitlab.com/runner/executors/docker.html#configure-a-docker-entrypoint
# Further more, this link shows an example based on those requirements which this script is based upon:
#   https://stackoverflow.com/questions/70401876/gitlab-runner-doesnt-run-entrypoint-scripts-in-dockerfile

# The CI variable is boolean that is set to true of we are running in the GitLab CI / CD environment
# so we execute a bash shell where the script block commands are piped into
if [[ -n "$CI" ]]; then
    exec /bin/bash
# Otherwise we are running outside, so execute the command line wrapper script directly
else
    exec $SCRIPT_DIR/extractDeploy.sh "$@"
fi
