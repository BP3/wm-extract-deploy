#!/bin/sh -e

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

# A utility script to identify the images we are using and push them into the
# local GitHub image registry.
# We do this because
#
#   a) It could save some time when downloading the images
#   b) It will certainly cut down on access to docker hub which is subject
#       to API Rate Limits
#
# Each image is copied from its upstream source with every platform it has (amd64, arm64, ...), so the test
# stacks run natively on Apple Silicon as well as on the amd64 GitHub runners. The copy goes registry to
# registry with 'docker buildx imagetools create', so nothing is pulled locally.
#
# Run from the repository root:
#
#   DRY_RUN=true tools/sync-images-to-ghcr.sh    # list what would be copied, and check the sources
#   tools/sync-images-to-ghcr.sh                 # copy (needs GHCR_PAT and GITHUB_USERNAME)
#
# GHCR_PAT is a classic personal access token with the write:packages scope.
#
# The images come from the 8.7 compose files, with the versions in .env, and from the Camunda 8.8 stacks (#123):
# their compose files (*-8.8-compose.yaml) and tools/images-8.8.txt, with the versions in .env-8.8.

target=ghcr.io/bp3

# Usage: upstream_for <image name>
# Where each image we mirror comes from. The compose files read the images from ghcr.io/bp3 (via .env or .env-8.8),
# so the upstream source has to be listed here.
upstream_for () {
  case $1 in
    camunda|zeebe|operate|identity|web-modeler-restapi|web-modeler-webapp|web-modeler-websockets)
      echo docker.io/camunda/$1 ;;
    elasticsearch)
      echo docker.elastic.co/elasticsearch/elasticsearch ;;
    postgres)
      echo docker.io/library/postgres ;;
    keycloak)
      # Bitnami removed its images from bitnami/keycloak; the same builds are kept in bitnamilegacy
      echo docker.io/bitnamilegacy/keycloak ;;
    camunda-keycloak)
      # Camunda's own Keycloak image, used from 8.8. Mirrored under another name, as keycloak is Bitnami's
      echo docker.io/camunda/keycloak ;;
    mailpit)
      echo docker.io/axllent/mailpit ;;
    *)
      return 1 ;;
  esac
}

# Usage: image_refs <env file> [file...]
# Prints name:tag for each 'image:' line in the files, with the env file's registry and version variables filled in
image_refs () {
  (
    . ./$1
    shift
    [ $# -gt 0 ] || exit 0
    cat "$@" | grep -v '^ *#' | grep 'image:' | sed 's/.*image: *//' | while read imgRef; do
      # Use eval to de-reference the registry and version EnvVars, and basename to get just name:tag
      basename `eval echo "$imgRef"`
    done
  )
}

# Usage: platforms_of <image reference>
# Prints the image's platforms, e.g. "linux/amd64 linux/arm64"
platforms_of () {
  docker buildx imagetools inspect --format '{{json .Manifest}}' "$1" |
    jq -r '[.manifests[]?.platform | select(.os != "unknown") | "\(.os)/\(.architecture)"] | unique | join(" ")'
}

if [ "$DRY_RUN" != "true" ]; then
  # You will need to set GHCR_PAT and GITHUB_USERNAME locally for this command to work
  echo "$GHCR_PAT" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
fi

# Find which images we need, as name:tag: the 8.7 compose files with .env, and the 8.8 ones with .env-8.8
compose_87=`ls *-compose.yaml | grep -v -- '-8\.8-compose\.yaml$' || true`
compose_88=`ls *-8.8-compose.yaml 2>/dev/null || true`
images=`{ image_refs .env $compose_87; image_refs .env-8.8 tools/images-8.8.txt $compose_88; } | sort -u`

failed=0
for image in $images; do
  name=${image%%:*}
  tag=${image#*:}

  if ! upstream=`upstream_for $name`; then
    echo "$image: no upstream source listed in upstream_for, so not copied"
    failed=1
    continue
  fi

  source=$upstream:$tag
  if ! platforms=`platforms_of $source` || [ -z "$platforms" ]; then
    echo "$image: can't read $source"
    failed=1
    continue
  fi
  case " $platforms " in
    *" linux/arm64 "*) ;;
    *)
      echo "$image: $source has no linux/arm64 build ($platforms)"
      failed=1
      continue ;;
  esac

  if [ "$DRY_RUN" = "true" ]; then
    echo "$image: would copy $source ($platforms)"
  else
    echo "$image: copying $source ($platforms)"
    docker buildx imagetools create --tag $target/$image $source
    echo "$image: $target/$image now has `platforms_of $target/$image`"
  fi
done

if [ $failed -ne 0 ]; then
  echo "Some images weren't copied. If the errors above say '429 Too Many Requests', Docker Hub's anonymous" \
    "download limit has been reached: log in with 'docker login' (any Docker Hub account) and run this again."
fi

exit $failed
