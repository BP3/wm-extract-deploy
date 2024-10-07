#!/bin/bash

source $SCRIPT_DIR/functions.sh

checkRequiredEnvVar CICD_ACCESS_TOKEN               "$CICD_ACCESS_TOKEN"
checkRequiredEnvVar CICD_REPOSITORY_PATH            "$CICD_REPOSITORY_PATH"

if [ "$CICD_PLATFORM" = "" ]; then
  CICD_PLATFORM=gitlab
  if [ -z "$CICD_SERVER_HOST" ]; then
    CICD_SERVER_HOST="gitlab.com"
  fi
elif [ "$CICD_PLATFORM" = "github" ]; then
  if [ -z "$CICD_SERVER_HOST" ]; then
    CICD_SERVER_HOST="github.com"
  fi
elif [ "$CICD_PLATFORM" = "bitbucket" ]; then
  if [ -z "$CICD_SERVER_HOST" ]; then
    CICD_SERVER_HOST="bitbucket.org"
  fi
fi
echo "The CI/CD platform is: $CICD_PLATFORM"

git config --global user.name "$GIT_USERNAME"
git config --global user.email $GIT_USER_EMAIL

if [ "$CICD_BRANCH" = "" ]; then
  CICD_BRANCH=main
fi
echo "Checkout branch: $CICD_BRANCH"
git checkout $CICD_BRANCH

python $SCRIPT_DIR/extract.py

git add *.bpmn
git add *.dmn
git add *.form
git add wm-project-id     # could change in the future
git status

# [skip ci] works across all the supported platforms
if [ "$COMMIT_MSG" = "" ]; then
  COMMIT_MSG="Updated by Camunda extract-deploy pipeline"
fi
if [ "$SKIP_CI" = "" -o "$SKIP_CI" = "true" ]; then
  COMMIT_MSG="${COMMIT_MSG} [skip ci]"
fi

git commit -m "${COMMIT_MSG}"

# If this is a new branch then this might not work in this form
# c.f. git push origin <new-branch>
# Probably needs some testing with branches
git push "$(getUrl "$CICD_PLATFORM" "$CICD_SERVER_HOST" "$CICD_ACCESS_TOKEN" "$CICD_REPOSITORY_PATH")"
