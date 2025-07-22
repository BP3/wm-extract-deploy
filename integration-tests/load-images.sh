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

composeFile=$1
envFile=.env

# Load environment variables
. ./$envFile

# Read compose file to find which images we need
grep 'image:' $composeFile | while read imageLine; do
  imgRef=`echo $imageLine | cut -d' ' -f2`
  # Use eval to de-reference the version EnvVar
  image=`eval echo "$imgRef"`
  docker pull $image
done
