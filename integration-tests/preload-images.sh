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


envFile=.env

# Load environment variables
. ./$envFile

echo $GHCR_PAT | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# Read compose file(s) to find which images we need
cat *-compose.yaml | grep -v '^#' | grep 'image:' | sort -u | while read imageLine; do

  # String off the "image: " prefix
  imgRef=`echo $imageLine | cut -d' ' -f2`

  # Use eval to de-reference the version EnvVar
  image=`eval echo "$imgRef"`

  # and basename to get just the image name
  ghcrName=ghcr.io/bp3/`basename $image`

  # Finally re-tag the image and push it to the registry
  docker tag $image $ghcrName
  echo "docker push $ghcrName"
  docker push $ghcrName

done

