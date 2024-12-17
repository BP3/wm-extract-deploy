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
import os
from model_action import ModelAction
from web_modeler import WebModeler, AuthException

class Extraction(ModelAction):

    def __init__(self, args):
        super().__init__(args)
        self.wm = WebModeler(args)

    def extract(self, items: dict):
        if not os.path.exists(self.model_path):
            os.makedirs(self.model_path)

        for item in items["items"]:
            file_path = self.model_path + "/" + item["simplePath"]
            print("Extracting item to {}".format(file_path))

            if item["canonicalPath"] is not None and item["canonicalPath"]:
                os.makedirs(os.path.dirname(file_path), exist_ok = True)

            data = self.wm.get_file_by_id(item["id"])["content"]
            with open(file_path, "w") as file:
                file.write(data)

    def main(self, args):
        self.wm.authenticate()

        project_id = self.wm.get_project(args.project)["id"]
        project_items = self.wm.list_files(project_id)

        self.extract(project_items)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(parents = [ModelAction.parser, WebModeler.parser])
    parser.add_argument("--project", help = "Modeler project id/name")
    args = parser.parse_args()
    try:
        Extraction(args).main(args)
    except AuthException as ex:
        print(ex)
        exit(3)
