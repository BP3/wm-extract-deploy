checkRequiredEnvVar() {
  if [ "$2" == "" ]; then
    echo "EnvVar '$1' is not set"
    exit 1
  fi
}

getGitLabUrl() {
  echo "https://gitlab-ci-token:$1@$2/$3.git"
}

getGitHubUrl(){
  echo "https://$1@$2/$3.git"
}

getBitBucketUrl() {
  echo "https://x-token-auth:$1@$2/$3.git"
}

getUrl() {
  CICD_PLATFORM=$(echo "$1" | tr "[:upper:]" "[:lower:]")
  CICD_SERVER_HOST=$2
  CICD_ACCESS_TOKEN=$3
  CICD_REPOSITORY_PATH=$4

  URL=""
  if [ $CICD_PLATFORM = "gitlab" ]; then

    URL="$(getGitLabUrl "$CICD_ACCESS_TOKEN" "$CICD_SERVER_HOST" "$CICD_REPOSITORY_PATH")"

  elif [ "$CICD_PLATFORM" = "github" ]; then

    URL="$(getGitHubUrl "$CICD_ACCESS_TOKEN" "$CICD_SERVER_HOST" "$CICD_REPOSITORY_PATH")"

  elif [ "$CICD_PLATFORM" = "bitbucket" ]; then

    URL="$(getBitBucketUrl "$CICD_ACCESS_TOKEN" "$CICD_SERVER_HOST" "$CICD_REPOSITORY_PATH")"

  fi

  echo "$URL"
}
