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
from typing import List
from pyzeebe import (
    ZeebeClient,
    create_camunda_cloud_channel,
    create_insecure_channel
)
from action import ModelAction

class Deployment(ModelAction):
    cluster_port = 26500
    zeebe_client = None
    cluster_host = None
    region = None
    cluster_id = None
    client_secret = None
    client_id = None
    tenant_ids: List[str] = None

    def __init__(self):
        super().__init__()

    def _check_env(self):
        # Just for debug for now
        super()._check_env()
        self._check_env_var('ZEEBE_CLIENT_ID', False)
        self._check_env_var('ZEEBE_CLIENT_SECRET')
        self._check_env_var('CAMUNDA_CLUSTER_ID', False)
        self._check_env_var('CAMUNDA_CLUSTER_REGION', False)
        self._check_env_var('CAMUNDA_CLUSTER_HOST', False)
        self._check_env_var('CAMUNDA_CLUSTER_PORT', False)


    def create_zeebe_client(self) -> None:
        if self.cluster_id is not None and self.cluster_id != "":
            grpc_channel = create_camunda_cloud_channel(
                client_id = self.client_id,
                client_secret = self.client_secret,
                cluster_id = self.cluster_id,
                region = self.region
            )
        else:
            grpc_channel = create_insecure_channel(
                grpc_address = self.cluster_host + ':' + str(self.cluster_port)
            )

        self.zeebe_client = ZeebeClient(grpc_channel)

    def deploy(self, models: List[str], tenant_id: str = None):
        self.create_zeebe_client()
        print("Deploying resources: {}".format(models))
        loop = asyncio.get_event_loop()
        loop.run_until_complete(self.deploy_resources(models, tenant_id))

    async def deploy_resources(self, resource_paths: list, tenant_id: str):
        return await self.zeebe_client.deploy_resource(*resource_paths, tenant_id = tenant_id)

    def main(self):
        self.client_id = os.environ["ZEEBE_CLIENT_ID"]
        self.client_secret = os.environ['ZEEBE_CLIENT_SECRET']

        if self._getenv("CAMUNDA_CLUSTER_ID") is not None:
            self.cluster_id = self._getenv("CAMUNDA_CLUSTER_ID")
            self.region = self._getenv("CAMUNDA_CLUSTER_REGION")

        if self._getenv("CAMUNDA_CLUSTER_HOST") is not None:
            self.cluster_host = self._getenv("CAMUNDA_CLUSTER_HOST")

        if self._getenv("CAMUNDA_CLUSTER_PORT") is not None:
            self.cluster_port = int(self._getenv("CAMUNDA_CLUSTER_PORT"))

        if self._getenv("CAMUNDA_TENANT_ID") is not None:
            self.tenant_ids = self._getenv("CAMUNDA_TENANT_ID").split(',')

        if not os.path.exists(self.model_path):
            raise FileNotFoundError("Model Path directory '{}' doesn't exist".format(self.model_path))

        models = []
        # Types we need to support according to:
        # https://docs.camunda.io/docs/next/apis-tools/zeebe-api/gateway-service/#input-deployresourcerequest
        for model_type in ("*.bpmn", "*.dmn", "*.form"):
            models.extend(glob.glob("{}/**/{}".format(self.model_path, model_type), recursive = True))
        # print("Found resources: ", models)

        if self.tenant_ids:
            for tenant in self.tenant_ids:
                self.deploy(models, tenant_id = tenant)
        else:
            self.deploy(models)


if __name__ == "__main__":
    Deployment().main()
