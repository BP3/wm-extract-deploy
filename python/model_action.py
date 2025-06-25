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

class ModelAction:
    parser = configargparse.ArgumentParser(add_help = False)
    parser.add_argument("--model-path", dest="model_path", help = "Model file path", env_var = "MODEL_PATH", default=".")

    def __init__(self, args):
        super().__init__()
        self.model_path = args.model_path
