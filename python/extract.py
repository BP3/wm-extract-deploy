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
from action import ModelAction
from web_modeler import WebModeler

class Extraction(ModelAction):

    def __init__(self):
        super().__init__()
        self.wm = WebModeler()

    def extract(self, items: dict):
        path = self.model_path

        if not os.path.exists(path):
            os.makedirs(path)

        for item in items["items"]:
            file_path = path + "/" + item["simplePath"]
            print("Extracting item to {}".format(file_path))

            if item["canonicalPath"] is not None and item["canonicalPath"]:
                os.makedirs(os.path.dirname(file_path), exist_ok = True)

            data = self.wm.get_file_by_id(item["id"])["content"]
            # print(item)
            with open(file_path, "w") as file:
                file.write(data)
                file.close()

    def main(self):
        self.wm.authenticate()

        project = self.wm.get_project(self._getenv("CAMUNDA_WM_PROJECT"))
        project_items = self.wm.list_files(project["items"][0]["id"])

        self.extract(project_items)


if __name__ == "__main__":
    Extraction().main()

