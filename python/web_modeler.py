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
from typing import IO


class WebModeler:
    # In the future we may need to override for Self Managed if the authentication mechanism is different
    SAAS_HOST = 'cloud.camunda.io'
    GRANT_TYPE = 'client_credentials'
    protocol = 'https'
    config_file = 'config.yml'

    def __init__(self):
        self.config_dict = None
        self.project = None
        self.access_token = None
        self.wm_api_url = None
        self.client_secret = None
        self.client_id = None
        self.auth_url = None
        self.audience = None
        self.wm_host = None
        self.scope = None
        self.auth_headers = {}
        self.set_wm_host(self.SAAS_HOST)
        self.platform = 'KEYCLOAK'
        self.__configure()

    def set_wm_host(self, wm_host: str): 
        self.wm_host = wm_host
        self.audience = 'api.' + wm_host
        if wm_host == self.SAAS_HOST:
            self.auth_url = self.protocol + '://login.' + wm_host + '/oauth/token'
            self.wm_api_url = self.protocol + '://modeler.' + wm_host + '/api'
        else:
            self.wm_api_url = self.protocol + '://' + wm_host + '/api'
        
    def set_oauth_token_url(self, oauth_token_url: str):
        self.auth_url = oauth_token_url
        self.auth_headers = {'Content-Type': 'application/x-www-form-urlencoded'}

    def set_client_id(self, client_id: str):
        self.client_id = client_id
        self.scope = self.client_id + '/.default'

    def set_client_secret(self, secret: str):
        self.client_secret = secret

    def get_auth_url(self) -> str:
        return self.auth_url

    def get_wm_api_url(self, version: int = 1) -> str:
        return '{}/v{}'.format(self.wm_api_url, version)

    def set_config_file(self, filename: str):
        self.config_file = filename

    def get_config_file(self) -> str:
        return self.config_file

    def get_protocol(self) -> str:
        return self.protocol

    def set_protocol(self, protocol: str):
        self.protocol = protocol

    def get_headers(self) -> dict:
        return {
            "Authorization": "Bearer {}".format(self.access_token),
            "Content-Type": "application/json"
        }

    def set_oauth_platform(self, platform: str):
        self.platform = platform.upper()

    def get_oauth_platform(self) -> str:
        return self.platform

    @staticmethod
    def parse_yaml_file(file: IO) -> dict:
        yaml_config = yaml.safe_load(file)
        print("Loaded YAML data:", yaml_config)
        return yaml_config

    @staticmethod
    def parse_json_file(file: IO) -> dict:
        json_config = json.load(file)
        print("Loaded JSON data:", json_config)
        return json_config

    # Authenticate to Camunda Web Modeler and get an access-token
    def authenticate(self) -> str:

        match self.platform:
            case 'ENTRA':
                data = {
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "scope": self.scope,
                    "grant_type": self.GRANT_TYPE
                }
            case 'KEYCLOAK':
                data = {
                    "client_id": self.client_id,
                    "client_secret": self.client_secret,
                    "audience": self.audience,
                    "grant_type": self.GRANT_TYPE
                }
            case _:
                raise ValueError(self.platform + ' is not a supported authentication platform type.')
        
        response = requests.post(self.get_auth_url(), data=data, headers=self.auth_headers)
        print("Authentication response", response.status_code)

        if response.status_code != 200:
            raise RuntimeError('Authentication failed: ', response.text)

        self.access_token = response.json()["access_token"]
        return self.access_token

    def search_project(self, key: str, name: str) -> dict:
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
            self.get_wm_api_url() + '/projects/search',
            json=body,
            headers=self.get_headers()
        )

        # print("Find project response", response.status_code)
        self.project = response.json()

        return self.project

    def search_files(self, project_id: str, name: str = None) -> dict:

        page = 0
        size = 50
        body = {
            "filter": {
                "projectId": project_id
            },
            "sort": [{
                "field": "created",
                "direction": "ASC"
            }],
            "page": page,
            "size": size
        }

        if name is not None:
            body["filter"]["name"] = name

        full_response = {
            "items": [],
            "size": 0
        }

        while True:
            response = requests.post(
                self.get_wm_api_url() + '/files/search',
                json=body,
                headers=self.get_headers()
            )

            if len(response.json()["items"]) > 0:
                full_response["items"].extend(response.json()["items"])
                if len(response.json()["items"]) < size:
                    break
            else:
                break

            body["page"] += 1

        full_response["size"] = len(full_response["items"])

        # print("Find project files response", response.status_code)

        return full_response

    def get_file_by_id(self, file_id: str) -> dict:

        response = requests.get(
            self.get_wm_api_url() + "/files/" + file_id,
            headers=self.get_headers()
        )

        # print("Retrieve file content response", response.status_code)
        return response.json()

    def __configure(self):
        # Required EnvVars
        self.set_client_id(os.environ["CAMUNDA_WM_CLIENT_ID"])
        self.set_client_secret(os.environ['CAMUNDA_WM_CLIENT_SECRET'])

        # Optional EnvVars
        try:
            if os.environ["CAMUNDA_WM_SSL"] is not None and os.environ["CAMUNDA_WM_SSL"] != "":
                if os.environ["CAMUNDA_WM_SSL"].lower() == "false":
                    self.set_protocol('http')
        except KeyError:
            pass

        try:
            if os.environ["CAMUNDA_WM_HOST"] is not None and os.environ["CAMUNDA_WM_HOST"] != "":
                self.set_wm_host(os.environ["CAMUNDA_WM_HOST"])
        except KeyError:
            pass

        try:
            if os.environ["WM_PROJECT_METADATA_FILE"] is not None and os.environ["WM_PROJECT_METADATA_FILE"] != "":
                self.set_config_file(os.environ["WM_PROJECT_METADATA_FILE"])
        except KeyError:
            pass

        try:
            if os.environ["OAUTH2_TOKEN_URL"] is not None and os.environ["OAUTH2_TOKEN_URL"] != "":
                self.set_oauth_token_url(os.environ["OAUTH2_TOKEN_URL"])
        except KeyError:
            pass

        try:
            if os.environ["OAUTH_PLATFORM"] is not None and os.environ["OAUTH_PLATFORM"] != "":
                self.set_oauth_platform(os.environ["OAUTH_PLATFORM"])
        except KeyError:
            pass

    def create_reference_file(self, data: dict):
        if not os.path.exists(self.config_file):
            with open(self.config_file, "w") as file:
                if self.config_file.endswith("yml") or self.config_file.endswith("yaml"):
                    file.write(yaml.dump(data))
                elif self.config_file.endswith("json"):
                    file.write(json.dumps(data))
                file.close()

    def load_project_config(self):

        project_config_files = [self.config_file, "config.yaml", "config.json"]

        for config_file in project_config_files:
            # Check to see if one of the config file options exists
            # If it does then read the configuration from it
            if self.config_dict is None and os.path.exists(config_file):
                with open(config_file, 'r') as file:
                    if config_file.endswith("yml") or config_file.endswith("yaml"):
                        self.config_dict = self.parse_yaml_file(file)
                        self.config_file = config_file
                    elif config_file.endswith("json"):
                        self.config_dict = self.parse_json_file(file)
                        self.config_file = config_file

    def get_project(self, project_ref: str) -> dict:

        project = None
        needs_config_file = False
        self.load_project_config()

        # If we loaded a config, search for the provided ID
        if self.config_dict is not None:
            project_id = self.config_dict["project"]["id"]
            project = self.search_project("id", project_id)
            if project is None or not project['items']:
                print("Project not found using project ID {} from {}".format(project_id, self.config_file))
                project = None
                needs_config_file = True

        # If we failed to find the configured project, or there was no config supplied then try looking it up by
        # the projectRef we were given
        if project is None:
            needs_config_file = True
            # It could be we were given the Id
            print("project_ref = '{}'".format(project_ref))
            if project_ref is not None and project_ref != "":
                project = self.search_project("id", project_ref)
                # If there are no 'items' then try looking up the project by name
                if project is not None and not project['items']:
                    project = self.search_project("name", project_ref)
                    if not project["items"] and project_ref is not None:
                        print("Project '{}' not found".format(project_ref))
            else:
                raise ValueError("Either a valid config file or 'CAMUNDA_WM_PROJECT' environment variable must be "
                                 "supplied.")

        if not project["items"]:
            raise ValueError("Web Modeler project not found")

        if needs_config_file:
            data = {
                "project": {
                    "id": project['items'][0]['id'],
                    "name": project["items"][0]["name"]
                }
            }
            self.create_reference_file(data)

        return project

    def post_file(self, project_id: str, name: str, file_type: str, content: str) -> dict:

        body = {
            "name": name,
            "projectId": project_id,
            "content": content,
            "fileType": file_type
        }

        response = requests.post(
            url=self.get_wm_api_url() + "/files",
            json=body,
            headers=self.get_headers()
        )

        print("Create file response", response.status_code)
        if response.status_code != 200:
            raise RuntimeError("Attempt to create file failed.", response.json())
        else:
            return response.json()

    def update_file(self, project_id: str, file_id: str, name: str, file_type: str, content: str, revision: int) \
            -> dict:

        body = {
            "name": name,
            "projectId": project_id,
            "content": content,
            "fileType": file_type,
            "revision": revision
        }

        response = requests.patch(
            url=self.get_wm_api_url() + "/files/" + file_id,
            json=body,
            headers=self.get_headers()
        )

        print("Update file response", response.status_code)
        if response.status_code != 200:
            raise RuntimeError("Attempt to update file failed.", response.json())
        else:
            return response.json()

    def create_milestone(self, file_id: str, name: str) -> dict:
        body = {
            "name": name,
            "fileId": file_id,
            "organizationPublic": True
        }

        response = requests.post(
            url=self.get_wm_api_url() + "/versions",
            json=body,
            headers=self.get_headers()
        )

        print("Create version response", response.status_code)

        if response.status_code == 404:
            # the 'versions' API is not available which means we are integrating with
            # a version of Camunda less than 8.7 - therefore try the 'milestones' API
            body = {
                "name": name,
                "fileId": file_id,
            }
            response = requests.post(
                url=self.get_wm_api_url() + "/milestones",
                json=body,
                headers=self.get_headers()
            )
            print("Create milestone response", response.status_code)

        if response.status_code != 200:
            raise RuntimeError("Attempt to create template version failed.", response.json())
        else:
            return response.json()
