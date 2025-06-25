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
import os
import re
from model_action import ModelAction
from web_modeler import WebModeler, NotFoundError, MultipleFoundError
from oauth import AuthenticationError

class Extraction(ModelAction):

    def __init__(self, args):
        super().__init__(args)
        self.wm = WebModeler(args)
        if args.exclude is not None:
            print(f"Excluding paths with segments that match {args.exclude}")
            self.exclude_pattern = re.compile(args.exclude)
        else:
            self.exclude_pattern = None

    def extract(self, items: dict):
        if not os.path.exists(self.model_path):
            os.makedirs(self.model_path)

        for item in items["items"]:
            file_path = self.model_path + "/" + item["simplePath"]

            segments = file_path.split(os.sep)
            included = True
            if self.exclude_pattern is not None:
                for segment in segments:
                    if self.exclude_pattern.search(segment):
                        included = False
                        break

            if included:
                print(f"Extracting item to {file_path}")
                if item["canonicalPath"] is not None and item["canonicalPath"]:
                    os.makedirs(os.path.dirname(file_path), exist_ok = True)

                data = self.wm.get_file_by_id(item["id"])["content"]
                with open(file_path, "w") as file:
                    file.write(data)

    def main(self):
        try:
            self.wm.authenticate()

            project_id = self.wm.get_project(args.project)["id"]
        except ValueError as error:
            print(error)
            parser.print_usage()
            exit(2)
        project_items = self.wm.list_files(project_id)

        self.extract(project_items)


if __name__ == "__main__":
    parser = configargparse.ArgumentParser(parents = [ModelAction.parser, WebModeler.parser],
                                           formatter_class=configargparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("--project", help = "Modeler project id/name", env_var = "CAMUNDA_WM_PROJECT")
    parser.add_argument("--exclude", help = "RegEx pattern of path segments to exclude from extraction", env_var = "EXCLUDE", default = "wmedIgnore")
    args = parser.parse_args()
    try:
        Extraction(args).main()
    except (AuthenticationError, NotFoundError, MultipleFoundError) as ex:
        print(ex)
        exit(3)
