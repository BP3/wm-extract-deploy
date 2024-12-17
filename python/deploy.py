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
import asyncio
import glob
import os
from typing import List
from pyzeebe import (
    ZeebeClient,
    create_camunda_cloud_channel,
    create_insecure_channel
)
from model_action import ModelAction

class Deployment(ModelAction):
    cluster_port = 26500
    zeebe_client = None
    cluster_host = None
    region = None
    cluster_id = None
    client_secret = None
    client_id = None
    tenant_ids: List[str] = None

    def __init__(self, args: argparse.Namespace):
        super().__init__(args)

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

    def main(self, args):
        self.client_id = args.client_id
        self.client_secret = args.client_secret

        if args.cluster_id is not None:
            self.cluster_id = args.cluster_id
            self.region = args.cluster_region
        else:
            self.cluster_host = args.cluster_host
            self.cluster_port = args.cluster_port

        if args.tenant_ids is not None:
            self.tenant_ids = args.tenant_ids.split(',')

        files = []
        # Types we need to support according to:
        # https://docs.camunda.io/docs/next/apis-tools/zeebe-api/gateway-service/#input-deployresourcerequest
        file_types = ("*.bpmn", "*.dmn", "*.form")
        for file_type in file_types:
            files.extend(glob.glob("{}/**/{}".format(self.model_path, file_type), recursive = True))
        if len(files) == 0:
            print("Didn't find any files to deploy in '{}' matching {}.".format(self.model_path, file_types))
            return

        # print("Found files: ", files)

        if self.tenant_ids:
            for tenant in self.tenant_ids:
                self.deploy(files, tenant_id = tenant)
        else:
            self.deploy(files)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(parents = [ModelAction.parser])
    parser.add_argument("--client-id", required = True, dest = "client_id", help = "Zeebe client ID")
    parser.add_argument("--client-secret", required = True, dest = "client_secret", help = "Zeebe client ID")
    cluster_group = parser.add_mutually_exclusive_group(required=True)
    cluster_group.add_argument("--cluster-id", dest ="cluster_id", help ="")
    cluster_group.add_argument("--cluster-host", dest ="cluster_host", help ="")
    cluster_secondary = parser.add_mutually_exclusive_group(required=True)
    cluster_secondary.add_argument("--cluster-region", dest = "cluster_region", help = "")
    cluster_secondary.add_argument("--cluster-port", type = int, dest = "cluster_port", help = "")
    parser.add_argument("--tenant-ids", dest = "tenant_ids", help = "")
    args = parser.parse_args()
    if args.cluster_id is not None and args.cluster_region is None:
        parser.print_usage()
        print("error: argument --cluster-region is required with argument --cluster-id")
        exit(2)
    if args.cluster_host is not None and args.cluster_port is None:
        parser.print_usage()
        print("error: argument --cluster-port is required with argument --cluster-host")
        exit(2)
    if not os.path.exists(args.model_path):
        print("error: argument --model-path: invalid path: '{}' does not exist".format(args.model_path))
        exit(2)
    Deployment(args).main(args)
