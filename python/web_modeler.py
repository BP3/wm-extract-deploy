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
import argparse
import requests
import os
import json
import yaml
from typing import IO

class AuthException(BaseException):
    pass

class WebModeler:
    __SAAS_HOST = 'cloud.camunda.io'
    protocol = 'https'
    config_file = 'config.yml'
    oauth2_token_url = None
    oauth_platform = 'KEYCLOAK'
    auth_headers = {}
    wm_host = __SAAS_HOST
    client_secret = None
    client_id = None
    __config = None
    __access_token = None

    parser = argparse.ArgumentParser(add_help = False)
    parser.add_argument("--client-id", dest="client_id", required = True, help = "Web Modeler client ID")
    parser.add_argument("--client-secret", dest="client_secret", required = True, help = "Web Modeler client secret")
    parser.add_argument("--host", help = "Web Modeler host")
    parser.add_argument("--oauth2-token-url", dest="oauth2_token_url", help = "OAuth2 Token URL")
    parser.add_argument("--oauth2-platform", dest="oauth2_platform", help = "OAuth2 platform (KEYCLOCK | ENTRA)")
    parser.add_argument("--ssl", nargs='?', const='true', default='false', help = "Web Modeler use SSL (HTTPS)")
    parser.add_argument("--config-file", dest="config_file", help = "Web Modeler project config file")

    def __init__(self, args: argparse.Namespace):
        super().__init__()
        self.client_id = args.client_id
        self.client_secret = args.client_secret
        if args.ssl is not None and args.ssl.lower() == 'false':
            self.protocol = 'http'
        if args.host is not None:
            self.wm_host = args.host
        if args.oauth2_token_url is not None:
            self.oauth2_token_url = args.oauth_token_url
            self.auth_headers = {'Content-Type': 'application/x-www-form-urlencoded'}
        if args.config_file is not None:
            self.config_file = args.config_file

        for config_file in [self.config_file, "config.yaml", "config.json"]:
            if os.path.exists(config_file):
                self.config_file = config_file
                print("Using config file:", config_file)
                break

    def __get_auth_url(self) -> str:
        if self.oauth2_token_url is not None:
            return self.oauth2_token_url
        else:
            return self.protocol + '://login.' + self.__SAAS_HOST + '/oauth/token'

    def __get_wm_api_url(self, version: int = 1) -> str:
        if self.wm_host == self.__SAAS_HOST:
            return self.protocol + '://modeler.' + self.wm_host + '/api/v' + version
        else:
            return self.protocol + '://' + self.wm_host + '/api/v' + version

    def __get_headers(self) -> dict:
        return {
            "Authorization": "Bearer {}".format(self.__access_token),
            "Content-Type": "application/json"
        }

    def set_oauth_platform(self, platform: str):
        self.platform = platform.upper()

    def get_oauth_platform(self) -> str:
        return self.platform

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
        data = {
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "grant_type": 'client_credentials'
        }
        match self.platform:
            case 'ENTRA':
                data.scope = self.client_id + "/.default"
            case 'KEYCLOAK':
                data.audience = "api." + self.wm_host
            case _:
                raise ValueError(self.platform + ' is not a supported authentication platform type.')

        response = requests.post(self.__get_auth_url(), data = data, headers=self.auth_headers)
        print("Authentication response", response.status_code)
        if response.status_code != 200:
            raise AuthException("Attempt to authenticate failed.", response.status_code, response.text)
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

    def __create_reference_file(self, data: dict):
        if not os.path.exists(self.config_file):
            with open(self.config_file, "w") as file:
                if self.config_file.endswith("yml") or self.config_file.endswith("yaml"):
                    file.write(yaml.dump(data))
                elif self.config_file.endswith("json"):
                    file.write(json.dumps(data))

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
        projects = None
        create_config_file = False
        self.__load_project_config()

        # If we loaded a config, search for the provided ID
        if self.__config is not None:
            project_id = self.__config["project"]["id"]
            projects = self.find_project("id", project_id)
            if projects is None:
                print("Project not found using project ID {} from {}".format(project_id, self.config_file))
            elif not projects['items']:
                print("Project not found using project ID {} from {}".format(project_id, self.config_file))
                projects = None

        # If we failed to find the specified project, or no config was supplied then try looking it up by projectRef
        if projects is None:
            create_config_file = True
            # It could be we were given the Id
            print("project_ref = '{}'".format(project_ref))
            if project_ref is not None and project_ref != "":
                projects = self.find_project("id", project_ref)
                # If there are no 'items' then try looking up the project by name
                if projects is not None and not projects['items']:
                    projects = self.find_project("name", project_ref)
                    if not projects["items"] and project_ref is not None:
                        print("Project '{}' not found".format(project_ref))
            else:
                raise ValueError("Either a valid config file or 'CAMUNDA_WM_PROJECT' environment variable must be "
                                 "supplied.")

        if not projects["items"]:
            raise ValueError("Web Modeler project not found")

        if not projects["items"].length > 1:
            raise ValueError("Web Modeler multiple projects found")

        project = projects['items'][0];

        if create_config_file:
            data = {
                "project": {
                    "id": project['id'],
                    "name": project["name"]
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
