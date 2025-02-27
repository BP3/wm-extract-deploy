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
import web_modeler


class Extraction:

    def __init__(self):
        self.model_path = env.DEFAULT_MODEL_PATH
        self.wm = web_modeler.WebModeler()
        self.check_env()

    @staticmethod
    def check_env():
        # Just debug for now
        env.check_env_var('CAMUNDA_WM_HOST', False)
        env.check_env_var('OAUTH2_TOKEN_URL', False)
        env.check_env_var('OAUTH_PLATFORM', False)
        env.check_env_var('CAMUNDA_WM_AUTH', False)
        env.check_env_var('CAMUNDA_WM_SSL', False)
        env.check_env_var('CAMUNDA_WM_CLIENT_ID', False)
        env.check_env_var('CAMUNDA_WM_CLIENT_SECRET')
        env.check_env_var('MODEL_PATH', False)

    def get_model_path(self) -> str:
        return self.model_path

    def set_model_path(self, model_path: str):
        self.model_path = model_path
        if not os.path.exists(self.model_path):
            os.makedirs(self.model_path)

    def extract(self, path: str, items: dict):

        for item in items["items"]:
            file_path = path + "/" + item["simplePath"]
            print("Extracting item to {}".format(file_path))

            if item["canonicalPath"] is not None and item["canonicalPath"]:
                os.makedirs(os.path.dirname(file_path), exist_ok=True)

            data = self.wm.get_file_by_id(item["id"])["content"]
            # print(item)
            with open(file_path, "w") as file:
                file.write(data)
                file.close()


if __name__ == "__main__":
    extract = Extraction()
    project_ref = None

    modelPath = os.environ["MODEL_PATH"]
    extract.set_model_path(modelPath)
    modelPath = extract.get_model_path()

    # Optional EnvVars
    try:
        if os.environ["CAMUNDA_WM_PROJECT"] is not None and os.environ["CAMUNDA_WM_PROJECT"] != "":
            project_ref = os.environ['CAMUNDA_WM_PROJECT']
    except KeyError:
        pass

    extract.wm.authenticate()

    project = extract.wm.get_project(project_ref)
    project_items = extract.wm.search_files(project["items"][0]["id"])

    extract.extract(modelPath, project_items)
