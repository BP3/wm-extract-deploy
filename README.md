# Extract and Deploy process models from Web Modeler
## Background
Web Modeler does not currently have support for the extraction and deployment of resources (i.e. BPMN and DMN models and Forms) to different CI / CD platforms such as GitLab, Github and Bitbucket -
this must be managed by the user through the [WM API](https://docs.camunda.io/docs/apis-tools/web-modeler-api/overview/).
The Web Modeler currently only has
* An option to deploy models directly to a Zeebe cluster (subject to the user having the right roles assigned)
* A native Github integration to allow users to synch the models to a repository (again, subject to the user having the right roles assigned)

## Solution
This project provides solutions to:
* Extract models from Web Modeler using the Web Modeler API, and
* Update a git repo with the extracted model
* Deploy a tagged version of the model to a target Zeebe cluster (environment)

To facilitate those operations, a Docker image is provided that is capable of 
those operations and that is suited for use in a DevOps pipeline. 
The operations are capable of working with any CI/CD platform and have so far been tested with:
* [GitLab](./GitLab.md)
* [Github](./Github.md)
* [Bitbucket](./BitBucket.md)

Follow the links above to better understand how to integrate extract & deploy operations into your
DevOps pipelines.

# Running the Docker container
The container can be run in the following modes, as described below:

## Extract
To extract process models from a Web Modeler project and commit to a local `git` repository:

For SaaS environments:
```shell
docker run -it --rm \
    --mount type=bind,src=${PWD},dst=/local --workdir /local \
      -e OAUTH2_CLIENT_ID="<Client Id>" \
      -e OAUTH2_CLIENT_SECRET="<Client secret>" \
      -e CAMUNDA_WM_PROJECT="<The WM project to extract from>" \
      -e GIT_USERNAME="<Git Username>" \
      -e GIT_USER_EMAIL="<Git Email address>" \
      -e SKIP_CI="<Indicate (\"true\" | \"false\") if you want to run any pipelines or not on the commit>" \
      -e CICD_PLATFORM="Indicate which SCM platform is being used, such as \"gitlab\", \"github\" or \"bitbucket\"" \
      -e CICD_SERVER_HOST="<The host of the GIT server. Only needed if using GitLab>" \
      -e CICD_ACCESS_TOKEN="<CI platform access token>" \
      -e CICD_REPOSITORY_PATH="<The path of the repository>" \
          bp3global/wm-extract-deploy extract
```

For Self managed environments:
```shell
docker run -it --rm \
    --mount type=bind,src=${PWD},dst=/local --workdir /local \
      -e OAUTH2_CLIENT_ID="<Client Id>" \
      -e OAUTH2_CLIENT_SECRET="<Client secret>" \
      -e OAUTH2_TOKEN_URL="<The OAuth2 Token URL>" \
      -e CAMUNDA_WM_PROJECT="<The WM project to extract from>" \
      -e CAMUNDA_WM_HOST="<Web Modeller hostname>" \
      -e GIT_USERNAME="<Git Username>" \
      -e GIT_USER_EMAIL="<Git Email address>" \
      -e SKIP_CI="<Indicate (\"true\" | \"false\") if you want to run any pipelines or not on the commit>" \
      -e CICD_PLATFORM="Indicate which SCM platform is being used, such as \"gitlab\", \"github\" or \"bitbucket\"" \
      -e CICD_SERVER_HOST="<The host of the GIT server. Only needed if using GitLab>" \
      -e CICD_ACCESS_TOKEN="<CI platform access token>" \
      -e CICD_REPOSITORY_PATH="<The path of the repository>" \
          bp3global/wm-extract-deploy extract
```

# Deploy
This will deploy the tagged commit to the target Zeebe cluster:

For SaaS deployments:
```shell
docker run -it --rm \
    --mount type=bind,src=${PWD},dst=/local --workdir /local \
      -e OAUTH2_CLIENT_ID="<Zeebe client Id>" \
      -e OAUTH2_CLIENT_SECRET="<Zeebe client secret>" \
      -e CAMUNDA_CLUSTER_ID="<Zeebe cluster Id>" \
      -e CAMUNDA_CLUSTER_REGION="<Zeebe region>" \
      -e CAMUNDA_TENANT_ID="<Optional tenant ID for multi-tenant>"
      -e PROJECT_TAG="<Optional - Code Repository Tag to Checkout.>" \
      -e CICD_BRANCH="<Optional - Code Branch to Checkout.>" \
      -e GIT_USERNAME="<Git Username>" \
      -e GIT_USER_EMAIL="<Git Email address>" \
          bp3global/wm-extract-deploy deploy
```

For Self Managed deployments:
```shell
docker run -it --rm \
    --mount type=bind,src=${PWD},dst=/local --workdir /local \
      -e OAUTH2_CLIENT_ID="<OAuth2 client Id>" \
      -e OAUTH2_CLIENT_SECRET="<OAuth2 client secret>" \
      -e OAUTH2_TOKEN_URL="<OAuth2 Token URL>" \
      -e CAMUNDA_CLUSTER_HOST="<Zeebe gateway hostname>" \
      -e CAMUNDA_CLUSTER_PORT="<Zeebe gateway port>" \
      -e CAMUNDA_TENANT_ID="<Optional tenant ID for multi-tenant>" \
      -e PROJECT_TAG="<Optional - Code Repository Tag to Checkout.>" \
      -e CICD_BRANCH="<Optional - Code Branch to Checkout.>" \
      -e GIT_USERNAME="<Git Username>" \
      -e GIT_USER_EMAIL="<Git Email address>" \
          bp3global/wm-extract-deploy deploy
```

# Deploy Templates
This will deploy connector templates from the current repo/directory and its subdirectories into the Web Modeler instance, and then commit the configuration file to the repository.

For SaaS environments:
```shell
docker run -it --rm \
    --mount type=bind,src=${PWD},dst=/local --workdir /local \
      -e OAUTH2_CLIENT_ID="<Client Id>" \
      -e OAUTH2_CLIENT_SECRET="<Client secret>" \
      -e CAMUNDA_WM_PROJECT="<The WM project to deploy the templates to>" \
      -e GIT_USERNAME="<Git Username>" \
      -e GIT_USER_EMAIL="<Git Email address>" \
      -e SKIP_CI="<Indicate (\"true\" | \"false\") if you want to run any pipelines or not on the commit>" \
      -e CICD_PLATFORM="Indicate which SCM platform is being used, such as \"gitlab\", \"github\" or \"bitbucket\"" \
      -e CICD_SERVER_HOST="<The host of the GIT server. Only needed if using GitLab>" \
      -e CICD_ACCESS_TOKEN="<CI platform access token>" \
      -e CICD_REPOSITORY_PATH="<The path of the repository>" \
          bp3global/wm-extract-deploy deploy templates
```

For Self managed environments:
```shell
docker run -it --rm \
    --mount type=bind,src=${PWD},dst=/local --workdir /local \
      -e OAUTH2_CLIENT_ID="<Client Id>" \
      -e OAUTH2_CLIENT_SECRET="<Client secret>" \
      -e OAUTH2_TOKEN_URL="<The OAuth2 Token URL>" \
      -e CAMUNDA_WM_PROJECT="<The WM project to deploy the templates to>" \
      -e CAMUNDA_WM_HOST="<Web Modeller hostname>" \
      -e GIT_USERNAME="<Git Username>" \
      -e GIT_USER_EMAIL="<Git Email address>" \
      -e SKIP_CI="<Indicate (\"true\" | \"false\") if you want to run any pipelines or not on the commit>" \
      -e CICD_PLATFORM="Indicate which SCM platform is being used, such as \"gitlab\", \"github\" or \"bitbucket\"" \
      -e CICD_SERVER_HOST="<The host of the GIT server. Only needed if using GitLab>" \
      -e CICD_ACCESS_TOKEN="<CI platform access token>" \
      -e CICD_REPOSITORY_PATH="<The path of the repository>" \
      -e OAUTH2_TOKEN_URL="<The OAuth2 Token URL>" \
          bp3global/wm-extract-deploy deploy templates
```

# Web Modeler project configuration

We support a couple of methods of specifying which Web Modeler project to interact with, either via the `CAMUNDA_WM_PROJECT` environment variable, or by providing a configuration file in the working directory/repository.

The configuration file can be either YAML or JSON and by default we will look for a file named `config.[yml|yaml|json]` in the working directory. If you wish to use an alternate name then this can be specified in the `WM_PROJECT_METADATA_FILE` environment variable. If a config file is not detected then one will be created after the first successful execution. 

The config file should contain a project element with a child id element where the value is the id of the project in Web Modeler (the guid in the URL when accessing the project), and optionally a name property.

e.g. in YAML:
```yaml
project:
  id: 571c8e5d-dcdf-41b5-bb42-e5f3ae593db9
  name: Connector Templates
```

# Supported Environment Variables

| EnvVar                   | Description                                                                                                    | Optional?                                                                                                                                    |
|--------------------------|----------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| CAMUNDA_CLUSTER_HOST     | The hostname or IP of the Camunda cluster gateway                                                              | Required for "deploy" operation in Self managed environments                                                                                 |
| CAMUNDA_CLUSTER_ID       | The Id of the Camunda SaaS cluster                                                                             | Required for "deploy" operation in SaaS environments                                                                                         |
| CAMUNDA_CLUSTER_PORT     | The port number of the Camunda cluster gateway                                                                 | Optional for "deploy" operation in Self managed environments (default = `26500`)                                                             |
| CAMUNDA_CLUSTER_REGION   | The region code the cluster is running in                                                                      | Required for "deploy" operation in SaaS environments                                                                                         |
| CAMUNDA_TENANT_ID        | A comma seperated list of the tenant id(s) to deploy to for multi-tenant environments                          | Optional for "deploy" operations (default = `NULL`)                                                                                          |
| CAMUNDA_WM_CLIENT_ID     | _Deprecated:_ see `OAUTH2_CLIENT_ID`                                                                           |                                                                                                                                              |
| CAMUNDA_WM_CLIENT_SECRET | _Deprecated:_ see `OAUTH2_CLIENT_SECRET`                                                                       |                                                                                                                                              |
| CAMUNDA_WM_HOST          | The hostname of the Web Modeler installation                                                                   | Optional (default = `cloud.camunda.io`)                                                                                                      |
| CAMUNDA_WM_PROJECT       | The name given to the Web Modeler Project that is to be extracted                                              | Optional for "extract" operation. If not provided then the project Id from `wm-project-id` file in the repository will be used)              |
| CAMUNDA_WM_SSL           | Whether to use an SSL connection or not                                                                        | Optional (default = `true`)                                                                                                                  |
| COMMIT_MSG               | The message applied to the extract commit                                                                      | Optional (default = `Updated by Camunda extract-deploy pipeline`)                                                                            |
| GIT_EMAIL                | The Git email address used for committing extracted Web Modeler files                                          | Required for "extract" operation                                                                                                             |
| GIT_USERNAME             | The Git user name used for committing extracted Web Modeler files                                              | Required for "extract" operation                                                                                                             |
| CICD_ACCESS_TOKEN        | The access token issued that provides permissions for remote Git operations                                    | Required for "extract" operation                                                                                                             |
| CICD_BRANCH              | The branch that the extracted model should be committed to                                                     | Optional (default = `main`)                                                                                                                  |
| CICD_PLATFORM            | Indicates which CI/CD platform is being used, with the supported options of "gitlab", "github" or "bitbucket"  | Required for "extract" operation                                                                                                             |
| CICD_REPOSITORY_PATH     | The project namespace with the project name included                                                           | Required for "extract" operation                                                                                                             |
| CICD_SERVER_HOST         | The GitLab server host                                                                                         | Optional for "extract" operation. For on-premise GitLab, otherwise defaults to "gitlab.com"                                                  |
| OAUTH2_TOKEN_URL         | The authentication endpoint URL for retrieving the OAuth2 token                                                | Required for Self managed web modeler and Zeebe operations                                                                                   |
| OAUTH2_CLIENT_ID         | The OAuth2 Client Id                                                                                           | Required for "extract" (Web modeler read access) and "deploy" (Zeebe write access), and "deployTemplates" (Web Modeler write/update access)  |
| OAUTH2_CLIENT_SECRET     | The OAuth2 Client Secret                                                                                       | Required for "extract"  (Web modeler read access), "deploy" (Zeebe write access), and "deployTemplates" (Web Modeler write/update access)    |
| OAUTH_PLATFORM           | _Deprecated:_ The OAuth2 platform in use                                                                       | Optional (default = KEYCLOAK, supported values: KEYCLOAK, ENTRA)                                                                             |
| PROJECT_TAG              | The label given to the tags created and also the tag that is checked out and deploy                            | Required for "deploy" operation                                                                                                              |
| SKIP_CI                  | Indicates if upon commit, we do or do not want any pipelines to be executed. The options are "true" or "false" | Required for "extract" operation                                                                                                             |
| WM_PROJECT_METADATA_FILE | The name of the web modeller project configuration file                                                        | Optional for operations involving web modeler (default = `config.yml` if none present, will look for`config.yml/yaml/json`)                  |
| ZEEBE_CLIENT_ID          | Deprecated: see `OAUTH2_CLIENT_ID`                                                                             |                                                                                                                                              |
| ZEEBE_CLIENT_SECRET      | Deprecated: see `OAUTH2_CLIENT_SECRET`                                                                         |                                                                                                                                              |
| NO_GIT_FETCH             | Specify as TRUE to skip git fetch when deploying                                                               | Required when running deploy.sh in AWS CodeDeploy                                                                                            |

# Python runtime version issue
Currently, Python 3.11 is used as the base image - even though there are later versions of python available (at time of writing 3.12 is available).

When we try with python versions greater than 3.11 then the “deploy” operation fails with the following error message. 
As you can see the error is actually in the `pyzeebe` client even though we are using the latest version. 
Once the underlying error in `pyzeebe` is resolved, then we should be able to support a more up-to-date version of python.

```shell
/scripts/deploy.py:46: DeprecationWarning: There is no current event loop
  loop = asyncio.get_event_loop()
Traceback (most recent call last):
  File "/scripts/deploy.py", line 78, in <module>
    deploy.deploy(models)
  File "/scripts/deploy.py", line 47, in deploy
    loop.run_until_complete(self.deploy_resources(models))
  File "/usr/local/lib/python3.12/asyncio/base_events.py", line 685, in run_until_complete
    return future.result()
           ^^^^^^^^^^^^^^^
  File "/scripts/deploy.py", line 50, in deploy_resources
    return await self.zeebeClient.deploy_process(*resource_paths)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.12/site-packages/pyzeebe/client/client.py", line 122, in deploy_process
    await self.zeebe_adapter.deploy_process(*process_file_path)
  File "/usr/local/lib/python3.12/site-packages/pyzeebe/grpc_internals/zeebe_process_adapter.py", line 84, in deploy_process
    return await self._gateway_stub.DeployProcess(
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.12/site-packages/grpc/aio/_call.py", line 308, in __await__
    response = yield from self._call_response
               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
RuntimeError: Task <Task pending name='Task-1' coro=<Deployment.deploy_resources() running at /scripts/deploy.py:50> cb=[_run_until_complete_cb() at /usr/local/lib/python3.12/asyncio/base_events.py:181]> got Future <Task pending name='Task-2' coro=<UnaryUnaryCall._invoke() running at /usr/local/lib/python3.12/site-packages/grpc/aio/_call.py:577>> attached to a different loop
Task was destroyed but it is pending!
task: <Task pending name='Task-2' coro=<UnaryUnaryCall._invoke() running at /usr/local/lib/python3.12/site-packages/grpc/aio/_call.py:577>>
sys:1: RuntimeWarning: coroutine 'UnaryUnaryCall._invoke' was never awaited
```

# Using a local Zeebe docker stack for development
If you are running the extract/deploy app on the same host as the Zeebe docker stack (i.e. on a developer's computer), you need to make some changes to the Docker compose file for the Zeebe stack in order for the authentication to work between the local containers.

Assuming that you are using the docker compose files from the [Camunda Platform repo](https://github.com/camunda/camunda-platform); In the directory with the Camunda 8 docker-compose file you should edit the `.env` file and change the `HOST` variable from `localhost` to your host's IP address.

The Web Modeler docker compose does not use these environment variables, so we need to update them individually. Open the `docker-compose-web-modeler.yaml` file in your text editor of choice and update the following environment variable lines, replacing `localhost` in the URLs with `${HOST}` while leaving the port number intact:

- RESTAPI_OAUTH2_TOKEN_ISSUER
- RESTAPI_SERVER_URL
- SERVER_URL
- OAUTH2_TOKEN_ISSUER

Save the changes and then create the docker container as usual. You will need to use your IP address rather than localhost when accessing any of the exposed services (i.e. Operate, Web Modeler etc.) but otherwise they should function as normal.

You now need to create a client app and secret for the extract-deploy app to use for accessing Web Modeler.
1. Open Identity in your browser (`https://<your IP address>:8084`) and log in.
2. Click `Add Application`, enter a name (this will be the Client ID), and select the `M2M` radio button, then click `Add`.
3. Click on the new Application you created and make a note of the Client secret as you will need this for the extract script.
4. Open the `Access to APIs` tab, click the `Assign Permissions` button and then select `Web Modeler API` from the dropdown. Select the read, write, and create permission checkboxes and then click the `Add` button.

## Building locally

`docker build -t bp3global/wm-extract-deploy .`
