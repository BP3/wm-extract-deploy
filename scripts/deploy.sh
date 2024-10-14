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

git fetch

git -c advice.detachedHead=false checkout tags/"$PROJECT_TAG"

python $SCRIPT_DIR/deploy.py
