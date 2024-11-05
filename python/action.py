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

class Action:
    @staticmethod
    def _check_env_var(name: str, secret: bool = True):
        value = Action._getenv(name)
        if value is not None:
            if secret:
                value = '************'
            print('    Found {} = {}'.format(name, value))
        else:
            print('    WARN: EnvVar {} value not set!'.format(name))

    @staticmethod
    def _getenv(name) -> str or None:
        value = os.getenv(name)
        if value == "":
            return None
        else:
            return value

    def _check_env(self):
        pass

class ModelAction(Action):
    model_path = os.environ["MODEL_PATH"]

    def __init__(self):
        super().__init__()
        self._check_env()

    def _check_env(self):
        super()._check_env()
