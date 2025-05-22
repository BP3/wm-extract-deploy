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
import grpc

from pyzeebe import (
    ZeebeClient,
    create_camunda_cloud_channel,
    create_insecure_channel,
    create_oauth2_client_credentials_channel
)


class Deployment:

    cluster_port = 26500

    def __init__(self):
        self.zeebe_client = None
        self.model_path = env.DEFAULT_MODEL_PATH
        self.cluster_host = None
        self.region = None
        self.cluster_id = None
        self.client_secret = None
        self.client_id = None
        self.tenant_ids = None
        self.authorization_server_url = None
        self.deploy_authorization = None
        self.check_env()

    @staticmethod
    def check_env():
        # Just for debug for now
        env.check_env_var('ZEEBE_CLIENT_ID', False)
        env.check_env_var('ZEEBE_CLIENT_SECRET')
        env.check_env_var('CAMUNDA_CLUSTER_ID', False)
        env.check_env_var('CAMUNDA_CLUSTER_REGION', False)
        env.check_env_var('CAMUNDA_CLUSTER_HOST', False)
        env.check_env_var('CAMUNDA_CLUSTER_PORT', False)
        env.check_env_var('MODEL_PATH', False)
        env.check_env_var('ZEEBE_AUTHORIZATION_SERVER_URL', False)
        env.check_env_var('DEPLOY_AUTHORIZATION', False)

    def set_client_id(self, client_id: str):
        self.client_id = client_id

    def set_client_secret(self, secret: str):
        self.client_secret = secret

    def set_cluster_id(self, cluster_id: str):
        self.cluster_id = cluster_id

    def set_region(self, region: str):
        self.region = region

    def set_cluster_host(self, host: str):
        self.cluster_host = host

    def set_cluster_port(self, port: int):
        self.cluster_port = port

    def get_model_path(self):
        return self.model_path

    def set_model_path(self, model_path: str):
        self.model_path = model_path

    def set_tenant_ids(self, tenant_ids: list[str]):
        self.tenant_ids = tenant_ids

    def set_authorization_server_url(self, authorization_server_url: str):
        self.authorization_server_url = authorization_server_url

    def set_deploy_authorization(self, deploy_authorization: str):
        self.deploy_authorization = deploy_authorization

    def create_zeebe_client(self) -> ZeebeClient:

        if self.cluster_id is not None and self.cluster_id != "":
            grpc_channel = create_camunda_cloud_channel(
                client_id=self.client_id,
                client_secret=self.client_secret,
                cluster_id=self.cluster_id,
                region=self.region
            )
        else:
            if self.deploy_authorization is None:
                grpc_channel = create_insecure_channel(
                    grpc_address=self.cluster_host + ':' + str(self.cluster_port)
                )
            elif self.deploy_authorization == "oauth2":
                grpc_channel = create_oauth2_client_credentials_channel(
                    grpc_address=self.cluster_host + ':' + str(self.cluster_port),
                    client_id=self.client_id,
                    client_secret=self.client_secret,
                    authorization_server=self.authorization_server_url,
                    audience="zeebe-api"
                )
            else:
                print("Unknown deployment authorization type: ", self.deploy_authorization)

        self.zeebe_client = ZeebeClient(grpc_channel)
        return self.zeebe_client

    def deploy(self, models: list[str], tenant_id: str = None):
        print("Deploying resources: {}".format(models))
        loop = asyncio.get_event_loop()
        loop.run_until_complete(self.deploy_resources(models, tenant_id))

    async def deploy_resources(self, resource_paths: list, tenant_id: str):
        return await self.zeebe_client.deploy_resource(*resource_paths, tenant_id=tenant_id)


if __name__ == "__main__":
    deploy = Deployment()

    deploy.set_client_id(os.environ["ZEEBE_CLIENT_ID"])
    deploy.set_client_secret(os.environ['ZEEBE_CLIENT_SECRET'])
    deploy.set_model_path(os.environ["MODEL_PATH"])
    deploy.set_deploy_authorization(os.environ["DEPLOY_AUTHORIZATION"])
    deploy.set_authorization_server_url(os.environ["ZEEBE_AUTHORIZATION_SERVER_URL"])

    try:
        if os.environ["CAMUNDA_CLUSTER_ID"] is not None and os.environ["CAMUNDA_CLUSTER_ID"] != "":
            deploy.set_cluster_id(os.environ["CAMUNDA_CLUSTER_ID"])
            deploy.set_region(os.environ["CAMUNDA_CLUSTER_REGION"])
    except KeyError:
        pass

    try:
        if os.environ["CAMUNDA_CLUSTER_HOST"] is not None and os.environ["CAMUNDA_CLUSTER_HOST"] != "":
            deploy.set_cluster_host(os.environ["CAMUNDA_CLUSTER_HOST"])
    except KeyError:
        pass

    try:
        if os.environ["CAMUNDA_TENANT_ID"] is not None and os.environ["CAMUNDA_TENANT_ID"] != "":
            deploy.set_tenant_ids(os.environ["CAMUNDA_TENANT_ID"].split(','))
    except KeyError:
        pass

    try:
        if os.environ["CAMUNDA_CLUSTER_PORT"] is not None and os.environ["CAMUNDA_CLUSTER_PORT"] != "":
            deploy.set_cluster_port(int(os.environ["CAMUNDA_CLUSTER_PORT"]))
    except KeyError:
        pass

    deploy.create_zeebe_client()

    modelPath = os.environ["MODEL_PATH"]
    deploy.set_model_path(modelPath)
    modelPath = deploy.get_model_path()

    if not os.path.exists(modelPath):
        message = "Model Path directory '{}' doesn't exist".format(modelPath)
        raise FileNotFoundError(message)

    # Types we need to support according to:
    # https://docs.camunda.io/docs/next/apis-tools/zeebe-api/gateway-service/#input-deployresourcerequest
    model_types = ("*.bpmn", "*.dmn", "*.form")
    models_list = []
    for model_type in model_types:
        models_list.extend(glob.glob("{}/**/{}".format(modelPath, model_type), recursive=True))
    # print("Found resources: ", models)

    if deploy.tenant_ids:
        for tenant in deploy.tenant_ids:
            deploy.deploy(models_list, tenant_id=tenant)
    else:
        deploy.deploy(models_list)
