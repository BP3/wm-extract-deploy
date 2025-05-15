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

import web_modeler
import env
import os
import glob
import json


class DeployTemplates:

    def __init__(self):
        self.project_id = None
        self.wm = web_modeler.WebModeler()
        self.check_env()

    def get_project_id(self) -> str:
        return self.project_id

    def set_project_id(self, project_id: str):
        self.project_id = project_id

    @staticmethod
    def check_env():
        # Just for debug for now
        env.check_env_var('CAMUNDA_WM_HOST', False)
        env.check_env_var('OAUTH2_TOKEN_URL', False)
        env.check_env_var('OAUTH_PLATFORM', False)
        env.check_env_var('CAMUNDA_WM_AUTH', False)
        env.check_env_var('CAMUNDA_WM_SSL', False)
        env.check_env_var('CAMUNDA_WM_CLIENT_ID', False)
        env.check_env_var('CAMUNDA_WM_CLIENT_SECRET')
        env.check_env_var('MODEL_PATH', False)

    def deploy_template(self, template_path: str):
        with open(template_path, 'r') as file:
            print("Processing template", template_path)

            content = json.load(file)
            source_version = content["version"]
            name = content["name"]
            file_id = None
            response = None

            # Check if file already exists in the project
            file_search = deployTemplates.wm.search_files(self.project_id, name)

            if len(file_search["items"]) > 0:
                file_id = file_search["items"][0]["id"]
                # WM overwrites the schema, id and version when uploaded so lets see if we have any changes first
                existing_content = json.loads(deployTemplates.wm.get_file_by_id(file_id)["content"])
                content["id"] = existing_content["id"]
                content["$schema"] = existing_content["$schema"]
                content["version"] = existing_content["version"]

                if content != existing_content:
                    response = deployTemplates.wm.update_file(
                        project_id=self.project_id,
                        file_id=file_id,
                        name=name,
                        file_type="connector_template",
                        content=json.dumps(content),
                        revision=file_search["items"][0]["revision"]
                    )
            else:
                response = deployTemplates.wm.post_file(
                    project_id=self.project_id,
                    name=name,
                    file_type="connector_template",
                    content=json.dumps(content)
                )
                if response is not None:
                    file_id = response["id"]

            if response is not None:
                milestone_response = deployTemplates.wm.create_milestone(
                    file_id=file_id,
                    name=source_version
                )
                if milestone_response is not None:
                    print("Created template version", milestone_response["name"])

            file.close()


if __name__ == "__main__":
    deployTemplates = DeployTemplates()
    project_ref = None

    # Optional EnvVars
    try:
        if os.environ["CAMUNDA_WM_PROJECT"] is not None and os.environ["CAMUNDA_WM_PROJECT"] != "":
            project_ref = os.environ['CAMUNDA_WM_PROJECT']
    except KeyError:
        pass

    deployTemplates.wm.authenticate()
    deployTemplates.set_project_id(deployTemplates.wm.get_project(project_ref)['items'][0]['id'])

    templates = glob.glob("./**/element-templates/*.json", recursive=True)
    print("Found templates:", templates)

    for template in templates:
        deployTemplates.deploy_template(template)
