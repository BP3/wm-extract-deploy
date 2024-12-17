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

class ModelAction:
    model_path = None

    parser = argparse.ArgumentParser(add_help = False)
    parser.add_argument("--model-path", dest="model_path", required = True, help = "Model file path")

    def __init__(self, args):
        super().__init__()
        self.model_path = args.model_path
