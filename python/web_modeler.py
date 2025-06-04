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
import configargparse
import requests
import os
import json
import yaml
from oauth import OAuth2

class NotFoundError(Exception):
    def __init__(self, resource_type: str, key: str = None, value: str = None):
        super().__init__(f"{resource_type} with {key} = '{value}' not found.")
        self.resource_type = resource_type
        self.key = key
        self.value = value

class MultipleFoundError(Exception):
    def __init__(self, resource_type: str, values: dict):
        super().__init__(f"Found multiple {resource_type}s: {values}")
        self.resource_type = resource_type
        self.values = values

class WebModeler:
    __SAAS_HOST: str = 'modeler.cloud.camunda.io'

    parser = configargparse.ArgumentParser(parents=[OAuth2.parser], add_help=False)
    parser.add_argument("--host", help="Web Modeler host",
                        env_var="CAMUNDA_WM_HOST", default='modeler.cloud.camunda.io')
    parser.add_argument("--ssl", nargs='?', const='true', help="Web Modeler use SSL (HTTPS)",
                        env_var="CAMUNDA_WM_SSL", default='false')
    parser.add_argument("--config-file", dest="config_file", help="Web Modeler project config file",
                        env_var="WM_PROJECT_METADATA_FILE", default="config.yml")
    parser.add_argument("--oauth2-platform", dest="oauth2_platform", help="OAuth2 platform. Deprecated: Use scope and audience instead",
                        env_var="OAUTH_PLATFORM", choices=['KEYCLOAK', 'ENTRA'], default='KEYCLOAK', deprecated = True )


    def __init__(self, args: configargparse.Namespace):
        super().__init__()
        self.oauth = OAuth2(args)

        # TODO replace this with web modeler url
        # Current options require port to be specified with the host which is not intuitive
        if args.ssl is not None and args.ssl.lower() == 'false':
            self.protocol = 'http'
        else:
            self.protocol = 'https'

        self.wm_host = args.host

        if self.oauth.token_url is None:
            if self.wm_host == WebModeler.__SAAS_HOST:
                self.oauth.token_url = 'https://login.cloud.camunda.io/oauth/token'
            else:
                raise ValueError("OAuth token url must be specified for self managed hosts.")

        self.__wm_api_url = f"{self.protocol}://{self.wm_host}/api/v1"

        match args.oauth2_platform:
            case 'ENTRA':
                self.oauth.scope = self.oauth.client_id + "/.default"
            case 'KEYCLOAK':
                self.oauth.audience = "api." + self.wm_host
            case _:
                raise ValueError(args.oauth2_platform + ' is not a supported authentication platform type.')

        self.__config = None
        self.config_file = args.config_file

    def __get_headers(self) -> dict:
        return self.oauth.headers() | {
            "Content-Type": "application/json"
        }

    def authenticate(self) -> None:
        self.oauth.authenticate()

    def find_project(self, key: str, value: str) -> dict:
        headers = self.__get_headers()
        url = self.__wm_api_url + '/projects/search'
        try:
            response = requests.post(
                url,
                json={
                    "filter": {
                        key: value
                    },
                    "sort": [{
                        "field": "created",
                        "direction": "ASC"
                    }]
                },
                headers=headers
            )
            # print("Find project response", response.status_code)
            if response.status_code == 404:
                raise NotFoundError("Project", key, value)
            elif response.status_code == 401:
                raise RuntimeError("Find project failed:", response.status_code, response.text, response.headers["www-authenticate"])
            elif response.status_code != 200:
                raise RuntimeError("Find project failed:", response.status_code, response.text)
            return response.json()
        except requests.exceptions.ConnectionError as ex:
            print(f"Error while finding project: {ex}")
            exit(3)

    def list_files(self, project_id: str, name: str = None) -> dict:
        page = 0
        size = 50

        full_response = {
            "items": [],
            "size": 0
        }
        while True:
            response = requests.post(
                self.__wm_api_url + '/files/search',
                json = {
                    "filter": {
                        "projectId": project_id,
                        "name": name
                    },
                    "sort": [{
                        "field": "created",
                        "direction": "ASC"
                    }],
                    "page": page,
                    "size": size
                },
                headers = self.__get_headers()
            )
            if response.status_code != 200:
                raise RuntimeError(f"List files for project {project_id} failed:", response.status_code, response.text)

            if len(response.json()["items"]) > 0:
                full_response["items"].extend(response.json()["items"])
                if len(response.json()["items"]) < size:
                    break
            else:
                break

            page += 1

        full_response["size"] = len(full_response["items"])

        return full_response

    def get_file_by_id(self, file_id: str) -> dict:
        response = requests.get(
            self.__wm_api_url + "/files/" + file_id,
            headers = self.__get_headers()
        )
        # print("Retrieve file content response", response.status_code)
        return response.json()

    def __create_config_file(self, data: dict):
        if not os.path.exists(self.config_file):
            with open(self.config_file, "w") as file:
                if self.config_file.endswith("yml") or self.config_file.endswith("yaml"):
                    file.write(yaml.dump(data))
                elif self.config_file.endswith("json"):
                    file.write(json.dumps(data))

    def __delete_config_file(self) -> None:
        if os.path.exists(self.config_file):
            os.remove(self.config_file)

    def __load_config_file(self):
        # Check to see if the config file exists
        # If it does, then read the configuration from it
        if self.__config is None and os.path.exists(self.config_file):
            with open(self.config_file, 'r') as file:
                if self.config_file.endswith("yml") or self.config_file.endswith("yaml"):
                    self.__config = yaml.safe_load(file)
                elif self.config_file.endswith("json"):
                    self.__config = json.load(file)
                print(f"Loaded config {self.__config} from {self.config_file}")

    def get_project(self, project_ref: str) -> dict:
        projects = None
        create_config_file = False
        self.__load_config_file()

        # If we loaded a config, search for the provided ID
        if self.__config is not None:
            project_ = self.__config["project"]
            if project_ref is not None and project_ref != project_["name"]:
                print(f"The project '{project_ref}' does not match the project '{project_["name"]}' from {self.config_file}, ignoring contents and regenerating.")
                self.__delete_config_file()
                projects = None
            else:
                project_id = project_["id"]
                projects = self.find_project("id", project_id)
                if projects is None:
                    print(f"Project not found using project ID {project_id} from {self.config_file}")
                elif not projects['items']:
                    print(f"Project not found using project ID {project_id} from {self.config_file}")
                    projects = None

        # If we failed to find the specified project, or no config was supplied, then try looking it up by project_ref
        if projects is None:
            create_config_file = True
            # First, try by id
            # print(f"project_ref = '{project_ref}'")
            if project_ref is not None and project_ref != "":
                projects = self.find_project("id", project_ref)
                # Then try by name
                if projects is not None and not projects['items']:
                    projects = self.find_project("name", project_ref)
            else:
                raise ValueError("A project was not specified. Specify it via config file, argument, or environment variable.")

        if not projects["items"]:
            raise NotFoundError("Project", "id", project_ref)

        if len(projects["items"]) > 1:
            raise MultipleFoundError("Project", projects["items"])

        project = projects['items'][0]

        if create_config_file:
            self.__create_config_file({
                "project": {
                    "id": project['id'],
                    "name": project["name"]
                }
            })

        return project

    def post_file(self, project_id: str, name: str, file_type: str, content: str) -> dict:
        body = {
            "name": name,
            "projectId": project_id,
            "content": content,
            "fileType": file_type
        }

        response = requests.post(
            url =self.__wm_api_url + "/files",
            json = body,
            headers = self.__get_headers()
        )

        if response.status_code != 200:
            raise RuntimeError("Attempt to create file failed.", response.json())
        return response.json()

    def update_file(self, project_id: str, file_id: str, name: str, file_type: str, content: str, revision: int) \
            -> dict:
        response = requests.patch(
            url =self.__wm_api_url + "/files/" + file_id,
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
            url = self.__wm_api_url + "/milestones",
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
