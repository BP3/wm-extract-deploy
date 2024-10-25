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

import asyncio
import glob
import os
import env

from pyzeebe import (
    ZeebeClient,
    create_camunda_cloud_channel,
    create_insecure_channel
)

class Deployment:

    def __init__(self):
        self.tenant_id = None
        self.env = env.Environment()
        self.checkEnv()

    # Just for debug for now
    def checkEnv(self):
        self.env.checkEnvVar('ZEEBE_CLIENT_ID', False)
        self.env.checkEnvVar('ZEEBE_CLIENT_SECRET')
        self.env.checkEnvVar('CAMUNDA_CLUSTER_ID', False)
        self.env.checkEnvVar('CAMUNDA_CLUSTER_REGION', False)
        self.env.checkEnvVar('CAMUNDA_CLUSTER_HOST', False)
        self.env.checkEnvVar('CAMUNDA_CLUSTER_PORT', False)
        self.env.checkEnvVar('MODEL_PATH', False)

    def setClientId(self, id):
        self.clientId = id

    def setClientSecret(self, secret):
        self.clientSecret = secret

    def setClusterId(self, id):
        self.clusterId = id

    def setRegion(self, region):
        self.region = region

    def setClusterHost(self, host):
        self.clusterHost = host

    def setClusterPort(self, port):
        self.clusterPort = port

    def getModelPath(self):
        return self.env.getModelPath()

    def setModelPath(self, modelPath):
        self.env.setModelPath(modelPath)

    def setTenantId(self, tenant_id: str):
        self.tenant_id = tenant_id

    def createZeebeClient(self):

        if hasattr(self, 'clusterId') and self.clusterId is not None and self.clusterId != "":
            grpc_channel = create_camunda_cloud_channel(
                client_id=self.clientId,
                client_secret=self.clientSecret,
                cluster_id=self.clusterId,
                region=self.region
            )
        else:
            grpc_channel = create_insecure_channel(
                grpc_address=self.clusterHost + ':' + self.clusterPort
            )

        self.zeebeClient = ZeebeClient(grpc_channel)
        return self.zeebeClient

    def deploy(self, model_list: list, tenant_id: str):
        print("Deploying resources: {}".format(model_list))
        loop = asyncio.get_event_loop()
        loop.run_until_complete(self.deploy_resources(model_list, tenant_id))

    async def deploy_resources(self, resource_paths: list, tenant_id: str):
        return await self.zeebeClient.deploy_resource(*resource_paths, tenant_id=tenant_id)


if __name__ == "__main__":
    deploy = Deployment()

    deploy.setClientId(os.environ["ZEEBE_CLIENT_ID"])
    deploy.setClientSecret(os.environ['ZEEBE_CLIENT_SECRET'])
    deploy.setModelPath(os.environ["MODEL_PATH"])

    try:
        if os.environ["CAMUNDA_CLUSTER_ID"] != None and os.environ["CAMUNDA_CLUSTER_ID"] != "":
            deploy.setClusterId(os.environ["CAMUNDA_CLUSTER_ID"])
            deploy.setRegion(os.environ["CAMUNDA_CLUSTER_REGION"])
    except KeyError:
        pass

    try:
        if os.environ["CAMUNDA_CLUSTER_HOST"] != None and os.environ["CAMUNDA_CLUSTER_HOST"] != "":
            deploy.setClusterHost(os.environ["CAMUNDA_CLUSTER_HOST"])
            deploy.setClusterPort(os.environ["CAMUNDA_CLUSTER_PORT"])
    except KeyError:
        pass

    try:
        if os.environ["CAMUNDA_TENANT_ID"] is not None and os.environ["CAMUNDA_TENANT_ID"] != "":
            deploy.setTenantId(os.environ["CAMUNDA_TENANT_ID"])
    except KeyError:
        pass

    deploy.createZeebeClient()

    modelPath = os.environ["MODEL_PATH"]
    deploy.setModelPath(modelPath)
    modelPath = deploy.getModelPath()

    if not os.path.exists(modelPath):
        message="Model Path directory '{}' doesn't exist".format(modelPath)
        raise FileNotFoundError(message)

    # Types we need to support according to: https://docs.camunda.io/docs/next/apis-tools/zeebe-api/gateway-service/#input-deployresourcerequest
    model_types = ("*.bpmn", "*.dmn", "*.form")
    models = []
    for model_type in model_types:
        models.extend(glob.glob("{}/**/{}".format(modelPath, model_type), recursive=True))
    # print("Found resources: ", models)

    deploy.deploy(models, tenant_id=deploy.tenant_id)
