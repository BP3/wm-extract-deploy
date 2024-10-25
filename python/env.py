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


DEFAULT_MODEL_PATH = 'model'


def check_env_var(name: str, secret: bool = True):
    try:
        value = os.environ[name]
        if value is not None and value != "":
            if secret:
                value = '************'
            print('    Found {} = {}'.format(name, value))
        else:
            print('    WARN: EnvVar {} value not set!'.format(name))
    except KeyError:
        print('    WARN: EnvVar {} not defined!'.format(name))
