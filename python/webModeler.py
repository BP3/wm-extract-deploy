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

import requests
import os
import json
import yaml

class webModeler:
    # In the future we may need to override for Self Managed if the authentication mechanism is different
    SAAS_HOST = 'cloud.camunda.io'
    wmHost = 'cloud.camunda.io'
    grantType = 'client_credentials'
    protocol = 'https'
    configFile = 'config.yml'

    def __init__(self):
        # self.env = env.Environment()
        self.setWMHost(self.wmHost)

    def setWMHost(self, wmHost):
        self.wmHost = wmHost
        self.audience = 'api.' + wmHost
        if wmHost == self.SAAS_HOST:
            self.authURL = self.protocol + '://login.' + wmHost + '/oauth/token'
            self.wmAPIURL = self.protocol + '://modeler.' + wmHost + '/api'
        else:
            self.authURL = self.setAuthHost(wmHost)
            self.wmAPIURL = self.protocol + '://' + wmHost + '/api'

    def setAuthHost(self, authHost):
        self.authURL = self.protocol + '://' + authHost + '/auth/realms/camunda-platform/protocol/openid-connect/token'

    def setClientId(self, id):
        self.clientId = id

    def setClientSecret(self, secret):
        self.clientSecret = secret

    def getAuthURL(self):
        return self.authURL

    def getWMAPIURL(self, version=1):
        return '{}/v{}'.format(self.wmAPIURL, version)

    def setConfigFile(self, filename):
        self.configFile = filename

    def getConfigFile(self):
        return self.configFile

    def getProtocol(self):
        return self.protocol

    def setProtocol(self, protocol):
        self.protocol = protocol

    def getHeaders(self):
        return {
            "Authorization": "Bearer {}".format(self.accessToken),
            "Content-Type": "application/json"
        }

    # Authenticate to Camunda Web Modeler and get an access token
    def authenticate(self):

        response = requests.post(self.getAuthURL(), data={
            "client_id": self.clientId,
            "client_secret": self.clientSecret,
            "audience": self.audience,
            "grant_type": self.grantType
        })

        print("Authentication response", response.status_code)

        self.accessToken = response.json()["access_token"]
        return self.accessToken

    def searchProject(self, key, name):
        body = {
            "filter": {
                key: name
            },
            "sort": [{
                "field": "created",
                "direction": "ASC"
            }]
        }

        response = requests.post(
            self.getWMAPIURL() + '/projects/search',
            json=body,
            headers=self.getHeaders()
        )

        print("Find project response", response.status_code)
        self.project = response.json()
        #TODO: Add error handling
        return self.project

    def searchFiles(self, id, name=None):
        body = {
            "filter": {
                "projectId": id
            },
            "sort": [{
                "field": "created",
                "direction": "ASC"
            }]
        }

        if name is not None:
            body["filter"]["name"] = name

        response = requests.post(
            self.getWMAPIURL() + '/files/search',
            json=body,
            headers=self.getHeaders()
        )

        # print("Find project files response", response.status_code)
        return response.json()

    def getFileById(self, id):

        response = requests.get(
            self.getWMAPIURL() + "/files/" + id,
            headers=self.getHeaders()
        )

        # print("Retrieve file content response", response.status_code)
        return response.json()

    def configure(self):
        # Required EnvVars
        self.setClientId(os.environ["CAMUNDA_WM_CLIENT_ID"])
        self.setClientSecret(os.environ['CAMUNDA_WM_CLIENT_SECRET'])

        # Optional EnvVars
        try:
            if os.environ["CAMUNDA_WM_SSL"] is not None and os.environ["CAMUNDA_WM_SSL"] != "":
                if os.environ["CAMUNDA_WM_SSL"].lower() == "false":
                    self.setProtocol('http')
        except KeyError:
            pass

        try:
            if os.environ["CAMUNDA_WM_HOST"] is not None and os.environ["CAMUNDA_WM_HOST"] != "":
                self.setWMHost(os.environ["CAMUNDA_WM_HOST"])
        except KeyError:
            pass

        try:
            if os.environ["CAMUNDA_WM_AUTH"] is not None and os.environ["CAMUNDA_WM_AUTH"] != "":
                self.setAuthHost(os.environ["CAMUNDA_WM_AUTH"])
        except KeyError:
            pass

        try:
            if os.environ["WM_PROJECT_METADATA_FILE"] != None and os.environ["WM_PROJECT_METADATA_FILE"] != "":
                self.setConfigFile(os.environ["WM_PROJECT_METADATA_FILE"])
        except KeyError:
            pass

    def createReferenceFile(self, configFile, data):
        if not os.path.exists(configFile):
            with open(configFile, "w") as file:
                if configFile.endswith("yml") or configFile.endswith("yaml"):
                    file.write(yaml.dump(data))
                elif configFile.endswith("json"):
                    file.write(json.dumps(data))
                file.close()

    def parseYamlConfig(self, file):
        yamlConfig = yaml.safe_load(file)
        print("Loaded YAML config:", yamlConfig)
        return yamlConfig

    def parseJsonConfig(self, file):
        jsonConfig = json.load(file)
        print("Loaded JSON config:", jsonConfig)
        return jsonConfig

    def loadProjectConfig(self):
        # We may want to make the following changes in the future:
        # - Pass in the file name using an env var, e.g. WM_PROJECT_METADATA_FILE
        # Specify if the file should be JSON or YAML, so it can contain other metadata items

        # This will look for (in order)
        #
        #   1. config.yml/yaml
        #   2. config.json
        #   3. wm-project-id - I can see this being dropped in the future
        #
        #   config.yml
        #   ----------
        #   project:
        #     id: <UUID>
        #     name:                       # Optional extension
        #
        #   config.json
        #   -----------
        #   {
        #     "project": {
        #       "id": "<UUID>",
        #       "name": "<project name>"    # Optional extension
        #      }
        #   }
        #
        #   wm-project-id
        #   -------------
        #   <UUID>

        projectConfigFiles=[self.configFile, "config.yaml", "config.json", "wm-project-id"]

        for configFile in projectConfigFiles:
            # Check to see if one of the config file options exists
            # If it does then read the configuration from it
            if not hasattr(self, "configDict") and os.path.exists(configFile):
                with open(configFile, 'r') as file:
                    if configFile.endswith("yml") or configFile.endswith("yaml"):
                        self.configDict = self.parseYamlConfig(file)
                        self.configFile = configFile
                    elif configFile.endswith("json"):
                        self.configDict = self.parseJsonConfig(file)
                        self.configFile = configFile
                    else:
                        self.configDict = {"project": {"id": file.read().strip()}}
                        self.configFile = configFile

    def getProject(self, projectRef):

        project = None
        needsConfigFile = False
        self.loadProjectConfig()

        # If we loaded a config, search for the provided ID
        if hasattr(self, "configDict") and self.configDict is not None:
            projectId = self.configDict["project"]["id"]
            project = self.searchProject("id", projectId)
            if project is None or not project['items']:
                print("Project not found using project ID {} from {}".format(projectId, self.configFile))
                project = None
                needsConfigFile = True
            elif self.configFile == "wm-project-id":
                needsConfigFile = True
                self.configFile = "config.yml"

        # If we failed to find the configured project, or there was no config supplied then try looking it up by
        # the projectRef we were given
        if project is None:
            needsConfigFile = True
            # It could be we were given the Id
            print("projectRef = '{}'".format(projectRef))
            if projectRef is not None and projectRef != "":
                project = self.searchProject("id", projectRef)
                # If there are no 'items' then try looking up the project by name
                if project is not None and not project['items']:
                    project = self.searchProject("name", projectRef)
                    if not project["items"] and projectRef is not None:
                        print("Project '{}' not found".format(projectRef))
            else:
                raise ValueError("Either a valid config file or 'CAMUNDA_WM_PROJECT' environment variable must be "
                                 "supplied.")

        if not project["items"]:
            raise ValueError("Web Modeler project not found")

        if needsConfigFile:
            data = {
                "project": {
                    "id": project['items'][0]['id'],
                    "name": project["items"][0]["name"]
                }
            }
            self.createReferenceFile(self.configFile, data)

        return project

    def postFile(self, projectId, name, filetype, content):

        body = {
            "name": name,
            "projectId": projectId,
            "content": content,
            "fileType": filetype
        }

        response = requests.post(
            url=self.getWMAPIURL() + "/files",
            json=body,
            headers=self.getHeaders()
        )

        #TODO: Improve exception handling
        print("PostFile response", response.status_code)
        if response.status_code != 200:
            print("Error Details", response.json())
        else:
            return response.json()

    def updateFile(self, projectId, fileId, name, filetype, content, revision):

        body = {
            "name": name,
            "projectId": projectId,
            "content": content,
            "fileType": filetype,
            "revision": revision
        }

        response = requests.patch(
            url=self.getWMAPIURL() + "/files/" + fileId,
            json=body,
            headers=self.getHeaders()
        )

        #TODO: Improve exception handling
        print("UpdateFile response", response.status_code)
        if response.status_code != 200:
            print("Error Details", response.json())
        else:
            return response.json()

    def createMilestone(self, fileId, name):
        body = {
            "name": name,
            "fileId": fileId
        }

        response = requests.post(
            url=self.getWMAPIURL() + "/milestones",
            json=body,
            headers=self.getHeaders()
        )

        #TODO: Improve exception handling
        print("CreateMilestone response", response.status_code)
        if response.status_code != 200:
            print("Error Details", response.json())
        else:
            return response.json()
