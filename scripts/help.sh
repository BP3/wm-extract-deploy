#!/bin/bash

echo Usage: extractDeploy.sh COMMAND
echo
echo A CI/CD automation wrapper for interacting with assets between a Camunda 8 Web Modeler project,
echo Zeebe cluster, and source control repositories.
echo
echo Available Commands:
echo "  extract            Extracts the assets from a web modeler project, and commits them to the repository."
echo "  deploy             Deploys the assets from the repository to the specified Zeebe cluster"
echo "  deploy templates   Deploys the Connector templates from the repository into Web Modeler"
echo
echo The configuration options for the commands are defined in environment variables as this is
echo intended to run as part of a CI/CD pipeline.
echo See https://github.com/BP3/wm-extract-deploy for more details.
