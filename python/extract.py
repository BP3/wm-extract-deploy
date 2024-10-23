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

import os
import env
import webModeler

class Extraction:

    # In the future we may need to override for Self Managed if the authentication mechanism is different
    SAAS_HOST = 'cloud.camunda.io'
    wmHost = 'cloud.camunda.io'
    grantType = 'client_credentials'
    protocol = 'https'
    configFile = 'config.yml'

    def __init__(self):
        self.env = env.Environment()
        self.wm = webModeler.webModeler()
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

    def getModelPath(self):
        return self.env.getModelPath()

    def setModelPath(self, modelPath):
        self.env.setModelPath(modelPath)
        if not os.path.exists(self.env.getModelPath()):
            os.makedirs(self.env.getModelPath())

    def extract(self, path, items):

        for item in items["items"]:
            file_path = path + "/" + item["simplePath"]
            print("Extracting item to {}".format(file_path))

            if(item["canonicalPath"] is not None and item["canonicalPath"]):
                os.makedirs(os.path.dirname(file_path), exist_ok=True)

            data = self.wm.getFileById(item["id"])["content"]
            # print(item)
            with open(file_path, "w") as file:
                file.write(data)
                file.close()


if __name__ == "__main__":
    extract = Extraction()
    projectRef = None

    modelPath = os.environ["MODEL_PATH"]
    extract.setModelPath(modelPath)
    modelPath = extract.getModelPath()

    # Optional EnvVars
    try:
        if os.environ["CAMUNDA_WM_PROJECT"] is not None and os.environ["CAMUNDA_WM_PROJECT"] != "":
            projectRef = os.environ['CAMUNDA_WM_PROJECT']
    except KeyError:
        pass

    extract.wm.configure()
    extract.wm.authenticate()

    project = extract.wm.getProject(projectRef)
    items = extract.wm.searchFiles(project["items"][0]["id"])

    extract.extract(modelPath, items)
