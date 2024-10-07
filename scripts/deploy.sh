#!/bin/bash

git -c advice.detachedHead=false checkout tags/"$PROJECT_TAG"

python $SCRIPT_DIR/deploy.py
