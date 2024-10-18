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

import webModeller
import env
import os
import glob
import json

class deployTemplates:
    wmHost = 'cloud.camunda.io'
    grantType = 'client_credentials'
    protocol = 'https'

    def __init__(self):
        self.env = env.Environment()
        self.wm = webModeller.webModeller()
        self.wm.setWMHost(self.wmHost)
        self.checkEnv()

    # Just for debug for now
    def checkEnv(self):
        self.env.checkEnvVar('CAMUNDA_WM_HOST', False)
        self.env.checkEnvVar('CAMUNDA_WM_AUTH', False)
        self.env.checkEnvVar('CAMUNDA_WM_SSL', False)
        self.env.checkEnvVar('CAMUNDA_WM_CLIENT_ID', False)
        self.env.checkEnvVar('CAMUNDA_WM_CLIENT_SECRET')
        self.env.checkEnvVar('MODEL_PATH', False)

if __name__ == "__main__":
    deployTemplates = deployTemplates()
    projectRef = None

    # Optional EnvVars
    try:
        if os.environ["CAMUNDA_WM_PROJECT"] is not None and os.environ["CAMUNDA_WM_PROJECT"] != "":
            projectRef = os.environ['CAMUNDA_WM_PROJECT']
    except KeyError:
        pass

    deployTemplates.wm.configure()
    deployTemplates.wm.authenticate()
    projectId = deployTemplates.wm.getProject(projectRef)['items'][0]['id']

    templates = glob.glob("./**/*.json", recursive=True)
    print("Found templates:", templates)

    for template in templates:
        with open(template, 'r') as file:
            print("Processing template", template)

            filetype = file.name.split(".")[-1]
            if filetype not in ["bpmn", "dmn", "form", "json"]:
                raise ValueError("Unsupported filetype in", file.name)

            content = json.load(file)

            if filetype == "json":
                name = content["name"]
                filetype = "connector_template"
            else:
                name = file.name.split(".")[-2].split("/")[-1]

            # Check if file already exists in the project
            fileSearch = deployTemplates.wm.searchFiles(projectId, name)

            if len(fileSearch["items"]) > 0:
                fileId = fileSearch["items"][0]["id"]
                # We need to use the ID and schema from the existing file in WM
                existingContent = json.loads(deployTemplates.wm.getFileById(fileId)["content"])
                content["id"] = existingContent["id"]
                content["$schema"] = existingContent["$schema"]
                content["version"] = existingContent["version"]

                if content != existingContent:
                    deployTemplates.wm.updateFile(
                        projectId=projectId,
                        fileId=fileId,
                        name=name,
                        filetype=filetype,
                        content=json.dumps(content),
                        revision=fileSearch["items"][0]["revision"]
                    )
            else:
                deployTemplates.wm.postFile(
                    projectId=projectId,
                    name=name,
                    filetype=filetype,
                    content=json.dumps(content)
                )
            file.close()
