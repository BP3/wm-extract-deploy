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
from action import Action

class WebModeler(Action):
    SAAS_HOST = 'cloud.camunda.io'
    GRANT_TYPE = 'client_credentials'
    protocol = 'https'
    config_file = 'config.yml'
    auth_host = SAAS_HOST
    wm_host = SAAS_HOST
    client_secret = None
    client_id = None
    __config = None
    __access_token = None

    def __init__(self):
        super().__init__()
        self.__configure()

    def __get_auth_url(self) -> str:
        if self.auth_host == self.SAAS_HOST:
            return self.protocol + '://login.' + self.auth_host + '/oauth/token'
        else:
            return self.protocol + '://' + self.auth_host + '/auth/realms/camunda-platform/protocol/openid-connect/token'

    def __get_wm_api_url(self, version: int = 1) -> str:
        if self.wm_host == self.SAAS_HOST:
            return self.protocol + '://modeler.' + self.wm_host + '/api/v' + version
        else:
            return self.protocol + '://' + self.wm_host + '/api/v' + version

    def __get_headers(self) -> dict:
        return {
            "Authorization": "Bearer {}".format(self.__access_token),
            "Content-Type": "application/json"
        }

    @staticmethod
    def __parse_yaml_file(file: IO) -> dict:
        yaml_config = yaml.safe_load(file)
        print("Loaded YAML data:", yaml_config)
        return yaml_config

    @staticmethod
    def __parse_json_file(file: IO) -> dict:
        json_config = json.load(file)
        print("Loaded JSON data:", json_config)
        return json_config

    # Authenticate to Camunda Web Modeler and get an access-token
    def authenticate(self) -> None:
        response = requests.post(self.__get_auth_url(), data = {
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "audience": 'api.' + self.wm_host,
            "grant_type": self.GRANT_TYPE
        })

        print("Authentication response", response.status_code)

        self.__access_token = response.json()["access_token"]

    def find_project(self, key: str, value: str) -> dict:
        response = requests.post(
            self.__get_wm_api_url() + '/projects/search',
            json = {
                "filter": {
                    key: value
                },
                "sort": [{
                    "field": "created",
                    "direction": "ASC"
                }]
            },
            headers = self.__get_headers()
        )
        # print("Find project response", response.status_code)
        return response.json()

    def list_files(self, project_id: str, name: str = None) -> dict:
        response = requests.post(
            self.__get_wm_api_url() + '/files/search',
            json = {
                "filter": {
                    "projectId": project_id,
                    "name": name
                },
                "sort": [{
                    "field": "created",
                    "direction": "ASC"
                }]
            },
            headers = self.__get_headers()
        )
        # print("Find project files response", response.status_code)
        return response.json()

    def get_file_by_id(self, file_id: str) -> dict:
        response = requests.get(
            self.__get_wm_api_url() + "/files/" + file_id,
            headers = self.__get_headers()
        )
        # print("Retrieve file content response", response.status_code)
        return response.json()

    def _check_env(self):
        # Just for debug for now
        super()._check_env()
        self._check_env_var('CAMUNDA_WM_HOST', False)
        self._check_env_var('CAMUNDA_WM_AUTH', False)
        self._check_env_var('CAMUNDA_WM_SSL', False)
        self._check_env_var('CAMUNDA_WM_CLIENT_ID', False)
        self._check_env_var('CAMUNDA_WM_CLIENT_SECRET')
        self._check_env_var('WM_PROJECT_METADATA_FILE', False)

    def __configure(self):
        self.client_id = os.environ["CAMUNDA_WM_CLIENT_ID"]
        self.client_secret = os.environ['CAMUNDA_WM_CLIENT_SECRET']

        if self._getenv("CAMUNDA_WM_SSL") is not None and self._getenv("CAMUNDA_WM_SSL").lower() == "false":
            self.protocol = 'http'

        if self._getenv("CAMUNDA_WM_HOST") is not None:
            self.wm_host = self._getenv("CAMUNDA_WM_HOST")

        if self._getenv("CAMUNDA_WM_AUTH") is not None:
            self.auth_host = self._getenv("CAMUNDA_WM_AUTH")

        if self._getenv("WM_PROJECT_METADATA_FILE") is not None:
            self.config_file = self._getenv("WM_PROJECT_METADATA_FILE")
        for config_file in [self.config_file, "config.yaml", "config.json"]:
            if os.path.exists(config_file):
                self.config_file = config_file


    def __create_reference_file(self, data: dict):
        if not os.path.exists(self.config_file):
            with open(self.config_file, "w") as file:
                if self.config_file.endswith("yml") or self.config_file.endswith("yaml"):
                    file.write(yaml.dump(data))
                elif self.config_file.endswith("json"):
                    file.write(json.dumps(data))
                file.close()

    def __load_project_config(self):
        # Check to see if the config file options exists
        # If it does then read the configuration from it
        if self.__config is None and os.path.exists(self.config_file):
            with open(self.config_file, 'r') as file:
                if self.config_file.endswith("yml") or self.config_file.endswith("yaml"):
                    self.__config = self.__parse_yaml_file(file)
                elif self.config_file.endswith("json"):
                    self.__config = self.__parse_json_file(file)

    def get_project(self, project_ref: str) -> dict:
        project = None
        create_config_file = False
        self.__load_project_config()

        # If we loaded a config, search for the provided ID
        if self.__config is not None:
            project_id = self.__config["project"]["id"]
            project = self.find_project("id", project_id)
            if project is None:
                print("Project not found using project ID {} from {}".format(project_id, self.config_file))
            elif not project['items']:
                print("Project not found using project ID {} from {}".format(project_id, self.config_file))
                project = None

        # If we failed to find the specified project, or no config was supplied then try looking it up by projectRef
        if project is None:
            create_config_file = True
            # It could be we were given the Id
            print("project_ref = '{}'".format(project_ref))
            if project_ref is not None and project_ref != "":
                project = self.find_project("id", project_ref)
                # If there are no 'items' then try looking up the project by name
                if project is not None and not project['items']:
                    project = self.find_project("name", project_ref)
                    if not project["items"] and project_ref is not None:
                        print("Project '{}' not found".format(project_ref))
            else:
                raise ValueError("Either a valid config file or 'CAMUNDA_WM_PROJECT' environment variable must be "
                                 "supplied.")

        if not project["items"]:
            raise ValueError("Web Modeler project not found")

        if create_config_file:
            data = {
                "project": {
                    "id": project['items'][0]['id'],
                    "name": project["items"][0]["name"]
                }
            }
            self.__create_reference_file(data)

        return project

    def post_file(self, project_id: str, name: str, file_type: str, content: str) -> dict:
        body = {
            "name": name,
            "projectId": project_id,
            "content": content,
            "fileType": file_type
        }

        response = requests.post(
            url =self.__get_wm_api_url() + "/files",
            json = body,
            headers = self.__get_headers()
        )

        print("Create file response", response.status_code)
        if response.status_code != 200:
            raise RuntimeError("Attempt to create file failed.", response.json())
        return response.json()

    def update_file(self, project_id: str, file_id: str, name: str, file_type: str, content: str, revision: int) \
            -> dict:
        response = requests.patch(
            url =self.__get_wm_api_url() + "/files/" + file_id,
            json = {
                "name": name,
                "projectId": project_id,
                "content": content,
                "fileType": file_type,
                "revision": revision
            },
            headers = self.__get_headers()
        )

        print("Update file response", response.status_code)
        if response.status_code != 200:
            raise RuntimeError("Attempt to update file failed.", response.json())
        return response.json()

    def create_milestone(self, file_id: str, name: str) -> dict:
        response = requests.post(
            url =self.__get_wm_api_url() + "/milestones",
            json = {
                "name": name,
                "fileId": file_id
            },
            headers = self.__get_headers()
        )

        print("Create milestone response", response.status_code)
        if response.status_code != 200:
            raise RuntimeError("Attempt to create milestone failed.", response.json())
        return response.json()
