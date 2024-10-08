import os
import json
import yaml
import requests
import env

class Extraction:

    # In the future we may need to override for Self Managed if the authentication mechanism is different
    SAAS_HOST = 'cloud.camunda.io'
    wmHost = 'cloud.camunda.io'
    grantType = 'client_credentials'
    protocol = 'https'
    configFile = 'config.yml'

    def __init__(self):
        self.env = env.Environment()
        self.setWMHost(self.wmHost)
        self.checkEnv()

    # Just for debug for now
    def checkEnv(self):
        self.env.checkEnvVar('CAMUNDA_WM_HOST', False)
        self.env.checkEnvVar('CAMUNDA_WM_AUTH', False)
        self.env.checkEnvVar('CAMUNDA_WM_SSL', False)
        self.env.checkEnvVar('CAMUNDA_WM_CLIENT_ID', False)
        self.env.checkEnvVar('CAMUNDA_WM_CLIENT_SECRET')
        self.env.checkEnvVar('MODEL_PATH', False)

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

    def setHeaders(self):
        return {
            "Authorization": "Bearer {}".format(self.accessToken),
            "Content-Type": "application/json"
        }

    def getProtocol(self):
        return self.protocol

    def setProtocol(self, protocol):
        self.protocol = protocol

    def setConfigFile(self, filename):
        self.configFile = filename

    def getConfigFile(self):
        return self.configFile

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
            if project == None or not project['items']:
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
            headers=self.setHeaders()
        )

        # print("Find project response", response.status_code)
        self.project = response.json()
        return self.project

    def searchFiles(self, id):
        body = {
            "filter": {
                "projectId": id
            },
            "sort": [{
                "field": "created",
                "direction": "ASC"
            }]
        }

        response = requests.post(
            self.getWMAPIURL() + '/files/search',
            json=body,
            headers=self.setHeaders()
        )

        # print("Find project files response", response.status_code)
        return response.json()

    def getFileById(self, id):

        response = requests.get(
            self.getWMAPIURL() + "/files/" + id,
            headers=self.setHeaders()
        )

        # print("Retrieve file content response", response.status_code)
        return response.json()

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

            data = self.getFileById(item["id"])["content"]
            # print(item)
            with open(file_path, "w") as file:
                file.write(data)
                file.close()

if __name__ == "__main__":
    extract = Extraction()
    projectRef = None

    # Required EnvVars
    extract.setClientId(os.environ["CAMUNDA_WM_CLIENT_ID"])
    extract.setClientSecret(os.environ['CAMUNDA_WM_CLIENT_SECRET'])

    modelPath = os.environ["MODEL_PATH"]
    extract.setModelPath(modelPath)
    modelPath = extract.getModelPath()

    # Optional EnvVars
    try:
        if os.environ["CAMUNDA_WM_SSL"] != None and os.environ["CAMUNDA_WM_SSL"] != "":
            if os.environ["CAMUNDA_WM_SSL"].lower() == "false":
                extract.setProtocol('http')
    except KeyError:
        pass

    try:
        if os.environ["CAMUNDA_WM_HOST"] != None and os.environ["CAMUNDA_WM_HOST"] != "":
            extract.setWMHost(os.environ["CAMUNDA_WM_HOST"])
    except KeyError:
        pass

    try:
        if os.environ["CAMUNDA_WM_AUTH"] != None and os.environ["CAMUNDA_WM_AUTH"] != "":
            extract.setAuthHost(os.environ["CAMUNDA_WM_AUTH"])
    except KeyError:
        pass

    try:
        if os.environ["CAMUNDA_WM_PROJECT"] != None and os.environ["CAMUNDA_WM_PROJECT"] != "":
            projectRef = os.environ['CAMUNDA_WM_PROJECT']
    except KeyError:
        pass

    try:
        if os.environ["WM_PROJECT_METADATA_FILE"] != None and os.environ["WM_PROJECT_METADATA_FILE"] != "":
            extract.setConfigFile(os.environ["WM_PROJECT_METADATA_FILE"])
    except KeyError:
        pass

    extract.authenticate()

    project = extract.getProject(projectRef)
    items = extract.searchFiles(project["items"][0]["id"])

    extract.extract(modelPath, items)
