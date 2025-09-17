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
import asyncio
import glob
import os
import logging
from typing import List, cast
from grpc.aio import AioRpcError
from pyzeebe import (
    ZeebeClient,
    create_camunda_cloud_channel,
    create_insecure_channel,
    create_oauth2_client_credentials_channel
)
from pyzeebe.errors import ZeebeGatewayUnavailableError, ProcessInvalidError

from model_action import ModelAction
from oauth import OAuth2

logger = logging.getLogger()

class Deployment(ModelAction):

    def __init__(self, args: configargparse.Namespace):
        super().__init__(args)
        self.oauth = OAuth2(args)
        if args.cluster_id is not None:
            self.cluster_id = args.cluster_id
            self.region = args.cluster_region
            self.cluster_host = None
            self.cluster_port = None
        else:
            self.cluster_id = None
            self.region = None
            self.cluster_host = args.cluster_host
            self.cluster_port = args.cluster_port

        if args.tenant_ids is not None:
            self.tenant_ids = args.tenant_ids.split(',')
        else:
            self.tenant_ids = None
        self.continue_on_error = args.continue_on_error

        self.zeebe_client = None

    def create_zeebe_client(self) -> None:
        if self.cluster_id is not None and self.cluster_id != "":
            grpc_channel = create_camunda_cloud_channel(
                client_id = self.oauth.client_id,
                client_secret = self.oauth.client_secret,
                cluster_id = self.cluster_id,
                region = self.region
            )
        elif self.cluster_host is not None and self.cluster_host != "":
            if self.oauth.client_id:
                grpc_channel = create_oauth2_client_credentials_channel(
                    grpc_address = self.cluster_host + ':' + str(self.cluster_port),
                    client_id = self.oauth.client_id,
                    client_secret = self.oauth.client_secret,
                    authorization_server = self.oauth.token_url,
                    audience = self.oauth.audience
                )
            else:
                grpc_channel = create_insecure_channel(
                    grpc_address = self.cluster_host + ':' + str(self.cluster_port)
                )
        else:
            raise ValueError("Cluster id or host must be specified")

        self.zeebe_client = ZeebeClient(grpc_channel)

    async def deploy(self, resource_file_paths: List[os.PathLike[str]], tenant_id: str = None) -> None:
        logger.info("Deploying resources: %s" + (" to tenant %s" if tenant_id is not None else "") + "...", resource_file_paths, tenant_id)
        if self.continue_on_error:
            for resource_file_path in resource_file_paths:
                try:
                    await self.zeebe_client.deploy_resource(resource_file_path, tenant_id = tenant_id)
                except Exception as x:
                    logger.exception("*** FILE: %s COULD NOT BE DEPLOYED ***", resource_file_path)
        else:
            await self.zeebe_client.deploy_resource(*resource_file_paths, tenant_id = tenant_id)

    async def main(self):
        # Types we need to support, according to:
        # https://docs.camunda.io/docs/next/apis-tools/zeebe-api/gateway-service/#input-deployresourcerequest
        file_types = ("*.bpmn", "*.dmn", "*.form")
        files = []
        for file_type in file_types:
            files.extend(glob.glob(f"{self.model_path}/**/{file_type}", recursive=True))
        if len(files) == 0:
            logger.warning("Didn't find any files to deploy in '%s' matching %s.", self.model_path, file_types)
            return

        logger.debug("Found files: %s", files)

        self.create_zeebe_client()
        try:
            await self.zeebe_client.healthcheck()

            if self.tenant_ids:
                await asyncio.gather(*[self.deploy(files, tenant_id=tenant) for tenant in self.tenant_ids])
            else:
                await self.deploy(files)
        except ZeebeGatewayUnavailableError as ex:
            logger.error(ex.grpc_error)
            exit(3)
        except ProcessInvalidError as ex:
            logger.error(cast(AioRpcError, ex.__cause__)._details)
            exit(3)


if __name__ == "__main__":
    parser = configargparse.ArgumentParser(parents = [ModelAction.parser, OAuth2.parser],
                                           formatter_class=configargparse.ArgumentDefaultsHelpFormatter)
    cluster_group = parser.add_mutually_exclusive_group(required = True)
    cluster_group.add_argument("--cluster-id", dest="cluster_id", help="For SaaS",
                               env_var="ZEEBE_CLUSTER_ID")
    cluster_group.add_argument("--cluster-host", dest="cluster_host", help="For self managed",
                               env_var="ZEEBE_CLUSTER_HOST")
    cluster_secondary = parser.add_mutually_exclusive_group(required = False)
    cluster_secondary.add_argument("--cluster-region", dest="cluster_region", help="For SaaS",
                                   env_var="ZEEBE_CLUSTER_REGION")
    cluster_secondary.add_argument("--cluster-port", type=int, dest="cluster_port", help="For self managed",
                                   env_var="ZEEBE_CLUSTER_PORT", default=26500)
    parser.add_argument("--tenant-ids", dest="tenant_ids", help="Comma separated list of tenant IDs", env_var="ZEEBE_TENANT_IDS")
    parser.add_argument("--continue-on-error", nargs="?", const=True, dest="continue_on_error",
                        help="Continue deploying files even if one has errors", env_var="CONTINUE_ON_ERROR", default=False)
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
        print(f"error: argument --model-path: invalid path: '{args.model_path}' does not exist")
        exit(2)
    asyncio.run(Deployment(args).main())
