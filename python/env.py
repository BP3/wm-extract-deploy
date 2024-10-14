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
# import requests

# from pyzeebe import (
#     ZeebeClient,
#     create_camunda_cloud_channel
# )

class Environment:

    defaultModelPath = 'model'

    def __init__(self):
        pass

    def checkEnvVar(self, name, secret=True):
        try:
            value = os.environ[name]
            if value != None and value != "":
                if secret == True:
                    value = '************'
                print('    Found {} = {}'.format(name, value))
            else:
                print('    WARN: EnvVar {} value not set!'.format(name))
        except KeyError:
            print('    WARN: EnvVar {} not defined!'.format(name))

    def getModelPath(self):
        return self.defaultModelPath

    def setModelPath(self, modelPath):
        if modelPath != "":
            self.defaultModelPath = modelPath

    # def createZeebeClient(self):
    #
    #     # In the future we may need to override for Self Managed if the authentication mechanism is different
    #     grpc_channel = create_camunda_cloud_channel(
    #         client_id=self.clientId,
    #         client_secret=self.clientSecret,
    #         cluster_id=self.clusterId,
    #         region=self.region
    #     )
    #
    #     self.zeebeClient = ZeebeClient(grpc_channel)
    #     return self.zeebeClient



if __name__ == "__main__":
    pass
