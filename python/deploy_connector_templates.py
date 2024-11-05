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
import glob
import json
from action import Action
from web_modeler import WebModeler

class DeployTemplates(Action):
    def __init__(self):
        super().__init__()
        self.wm = WebModeler()

    def deploy_template(self, template_path: str, project_id: str):
        print("Processing template", template_path)
        with open(template_path, 'r') as file:
            content = json.load(file)
            source_version = content["version"]
            name = content["name"]
            file_id = None
            response = None

            # Check if file already exists in the project
            files = self.wm.list_files(project_id, name)
            if len(files["items"]) > 0:
                file_id = files["items"][0]["id"]
                # WM overwrites the schema, id and version when uploaded so lets see if we have any changes first
                existing_content = json.loads(self.wm.get_file_by_id(file_id)["content"])
                content["id"] = existing_content["id"]
                content["$schema"] = existing_content["$schema"]
                content["version"] = existing_content["version"]

                if content != existing_content:
                    response = self.wm.update_file(
                        project_id = project_id,
                        file_id = file_id,
                        name = name,
                        file_type = "connector_template",
                        content = json.dumps(content),
                        revision = files["items"][0]["revision"]
                    )
            else:
                response = self.wm.post_file(
                    project_id = project_id,
                    name = name,
                    file_type = "connector_template",
                    content = json.dumps(content)
                )
                if response is not None:
                    file_id = response["id"]

            if response is not None:
                milestone_response = self.wm.create_milestone(
                    file_id = file_id,
                    name = source_version
                )
                if milestone_response is not None:
                    print("Created milestone", milestone_response["name"])

    def main(self):
        templates = glob.glob("./**/element-templates/*.json", recursive = True)
        print("Found templates:", templates)

        self.wm.authenticate()
        project_id = self.wm.get_project(self._getenv("CAMUNDA_WM_PROJECT"))['items'][0]['id']
        for template in templates:
            self.deploy_template(template, project_id)


if __name__ == "__main__":
    DeployTemplates().main()
