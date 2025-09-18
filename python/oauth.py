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
from argparse import _MutuallyExclusiveGroup

import configargparse
import logging
import requests
from oauthlib.oauth2 import BackendApplicationClient, OAuth2Error
from requests_oauthlib import OAuth2Session

logger = logging.getLogger()

class AuthenticationError(Exception):
    def __init__(self, status_code = None, response_text = None):
        super().__init__(f"Attempt to authenticate failed: {status_code} - {response_text}")
        self.status_code = status_code
        self.response_text = response_text


class OAuth2:
    @staticmethod
    def add_deprecated_options(client_id_group: _MutuallyExclusiveGroup, client_secret_group: _MutuallyExclusiveGroup):
        client_id_group.add_argument("--camunda-wm-client-id", dest="client_id", help = configargparse.SUPPRESS, #"Deprecated: Use --oauth-client-id instead",
                                     env_var = "CAMUNDA_WM_CLIENT_ID", deprecated = True)
        client_id_group.add_argument("--zeebe-client-id", dest="client_id", help = configargparse.SUPPRESS, #"Deprecated: Use --oauth-client-id instead",
                                     env_var = "ZEEBE_CLIENT_ID", deprecated = True)
        client_secret_group.add_argument("--camunda-wm-client-secret", dest="client_secret", help = configargparse.SUPPRESS, #"Deprecated: Use --oauth-client-secret instead",
                                         env_var = "CAMUNDA_WM_CLIENT_SECRET", deprecated = True)
        client_secret_group.add_argument("--zeebe-client-secret", dest="client_secret", help = configargparse.SUPPRESS, #"Deprecated: Use --oauth-client-secret instead",
                                         env_var = "ZEEBE_CLIENT_SECRET", deprecated = True)

    parser = configargparse.ArgumentParser(add_help = False)
    client_id_group = parser.add_mutually_exclusive_group(required = False)
    client_id_group.add_argument("--oauth2-client-id", dest="client_id", help = "OAuth2 client ID",
                        env_var = "OAUTH2_CLIENT_ID")
    client_secret_group = parser.add_mutually_exclusive_group(required = False)
    client_secret_group.add_argument("--oauth2-client-secret", dest="client_secret", help = "OAuth2 client secret",
                        env_var = "OAUTH2_CLIENT_SECRET")
    parser.add_argument("--oauth2-token-url", dest="token_url", help = "OAuth2 Token URL",
                        env_var = "OAUTH2_TOKEN_URL")
    parser.add_argument("--oauth2-audience", dest="audience", help = "OAuth2 audience",
                        env_var = "OAUTH2_AUDIENCE")
    parser.add_argument("--oauth2-grant-type", dest="grant_type", help = "OAuth2 grant type",
                        env_var = "OAUTH2_GRANT_TYPE", default = "client_credentials", choices = ["client_credentials", "password"])
    parser.add_argument("--oauth2-scope", dest="scope", help = "OAuth2 scope",
                        env_var = "OAUTH2_SCOPE")
    add_deprecated_options(client_id_group, client_secret_group)

    def __init__(self, args):
        super().__init__()
        self.token_url = args.token_url
        self.audience = args.audience
        self.grant_type = args.grant_type
        self.scope = args.scope
        self.client_id = args.client_id
        self.client_secret = args.client_secret
        self.__access_token = None

    def access_token(self):
        return self.__access_token

    def headers(self) -> dict:
        return {
            "Authorization": f"Bearer {self.__access_token}",
        }

    def authenticate(self) -> None:
        try:
            data = {
                "grant_type": self.grant_type,
            }
            if self.audience is not None:
                data["audience"] = self.audience
            client = BackendApplicationClient(client_id=self.client_id, scope=self.scope)
            oauth = OAuth2Session(client=client)
            os.environ["OAUTHLIB_INSECURE_TRANSPORT"] = "1"
            self.__access_token = oauth.fetch_token(token_url=self.token_url,
                                                    client_secret=self.client_secret,
                                                    kwargs=data)["access_token"]
        except OAuth2Error as ex:
            logger.exception("Error while authenticating")
            exit(3)
        except requests.exceptions.ConnectionError as ex:
            logger.exception("Error while retrieving OAuth token")
            exit(3)
