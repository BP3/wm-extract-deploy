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
import glob
import json
import logging

from model_action import ModelAction
from web_modeler import WebModeler, NotFoundError, MultipleFoundError
from oauth import AuthenticationError

logger = logging.getLogger()

class DeployTemplates(ModelAction):
    def __init__(self, args: configargparse.Namespace):
        super().__init__(args)
        self.wm = WebModeler(args)

    def deploy_template(self, template_path: str, project_id: str):
        logger.info("Processing template %s", template_path)
        with open(template_path, 'r') as file:
            content = json.load(file)
            source_version = content["version"]
            name = content["name"]
            file_id = None
            response = None

            # Check if the file already exists in the project
            files = self.wm.list_files(project_id, name)
            if len(files["items"]) > 0:
                file_id = files["items"][0]["id"]
                # WM overwrites the schema, id and version when uploaded, so update those
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
                    logger.info("\tNo changes to the template, skipping it.")
            else:
                try:
                    response = self.wm.post_file(
                        project_id = project_id,
                        name = name,
                        file_type = "connector_template",
                        content = json.dumps(content)
                    )
                    if response is not None:
                        file_id = response["id"]
                except RuntimeError as error:
                    logger.exception("\tError processing template %s", template_path)
                    return

            if response is not None:
                milestone_response = self.wm.create_milestone(
                    file_id = file_id,
                    name = source_version
                )
                if milestone_response is not None:
                    logger.info("Created milestone %s", milestone_response["name"])

    def main(self, args: configargparse.Namespace):
        templates = glob.glob(f"{self.model_path}/**/element-templates/*.json", recursive = True)
        if len(templates) == 0:
            logger.warning("No templates to deploy.")
            return

        logger.debug("Found templates: %s", templates)

        try:
            self.wm.authenticate()

            project_id = self.wm.get_project(args.project)["id"]
        except ValueError as error:
            logger.error(error)
            parser.print_usage()
            exit(2)

        for template in templates:
            self.deploy_template(template, project_id)


if __name__ == "__main__":
    parser = configargparse.ArgumentParser(parents = [ModelAction.parser, WebModeler.parser],
                                           formatter_class=configargparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("--project", help = "Modeler project id", env_var = "CAMUNDA_WM_PROJECT" )
    args = parser.parse_args()
    try:
        DeployTemplates(args).main(args)
    except (AuthenticationError, NotFoundError, MultipleFoundError) as ex:
        logger.error(ex)
        exit(3)
