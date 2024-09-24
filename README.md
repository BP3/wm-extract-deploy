# Extract, Tag and Deploy process models from Web Modeler
This is a project to explore some ideas around using a pipeline to:
* Extract models from Web Modeler using the Web Modeler API
* Update a git repo with the extracted model
* Deploy a tagged version of the model to a target Zeebe cluster (environment)

To facilitate those operations we will create a Docker image that is easily capable of 
those operations and that is suited for use in a pipeline. The extraction and tagging operations are capable of working with the following CI/CD platforms:
* GitLab
* GitHub
* Bit Bucket

## Background
Web Modeler does not currently have support for the extraction, tagging and deployment of resources (i.e. BPMN and DMN models and forms) to different CI / CD platforms such as GitLab, GitHub and Bit Bucket. This Docker image provides such capabilities that can be performed from a CI / CD pipeline, until such time that Camunda build these capabilities out.

The Web Modeller currently only has the ability to:
* Deploy models directly to a Zeebe cluster (subject to the user having the right roles assigned)
* A native GitHub integration to allow users to synch the models to a repository (again, subject to the user having the right roles assigned)

# Building the Docker image
The docker image is based on python which we are using as the underlying scripting language -
simply because it is widely used and well-supported with libraries. Specifically the
Camunda `pyzeebe` library which we use to deploy the extracted models to a Zeebe cluster.

To build the Docker image, run the following command:

```shell
docker build -t bp3global/wm-extract-deploy .
```

# Running the Docker container
The container can be run in three modes, as described below:

## Extract
To extract process models from Web Modeler project to a local `git` repository:

```shell
docker run -it --rm \
    --mount type=bind,src=${PWD},dst=/local --workdir /local \
    -e CAMUNDA_WM_CLIENT_ID="<Client Id>" \
    -e CAMUNDA_WM_CLIENT_SECRET="<Client secret>" \
    -e CAMUNDA_WM_PROJECT="<The WM project to extract from>" \
    -e GIT_USERNAME="<Git Username>" \
    -e GIT_USER_EMAIL="<Git Email address>" \
    -e SKIP_CI="<Indicate (\"true\" | \"false\") if you want to run any pipelines or not on the commit>" \
    -e CICD_PLATFORM="Indicate which SCM platform is being used, such as \"gitlab\", \"github\" or \"bitbucket\"" \
    -e CICD_SERVER_HOST="<The host of the GIT server. Only needed if using GitLab>" \
    -e CICD_ACCESS_TOKEN="<CI platform access token>" \
    -e CICD_REPOSITORY_PATH="<The path of the repository>" \
        bp3global/wm-extract-deploy:latest extract
```

## Tag
This will tag the tip of the specified branch:

```shell
docker run -it --rm \
    --mount type=bind,src=${PWD},dst=/local --workdir /local \
    -e CICD_PLATFORM="Indicate which SCM platform is being used, such as \"gitlab\", \"github\" or \"bitbucket\"" \
    -e CICD_SERVER_HOST="<The host of the GIT server. Only needed if using GitLab>" \
    -e CICD_ACCESS_TOKEN="<CI platform access token>" \
    -e CICD_REPOSITORY_PATH="<The path of the repository>" \
    -e PROJECT_TAG="<The tag to create>" \
        bp3global/wm-extract-deploy:latest tag
```

# Deploy
This will deploy the tagged commit to the target Zeebe cluster:

```shell
docker run -it --rm \
    --mount type=bind,src=${PWD},dst=/local --workdir /local \
    -e ZEEBE_CLIENT_ID="<Zeebe client Id>" \
    -e ZEEBE_CLIENT_SECRET="<Zeebe client secret>" \
    -e CAMUNDA_CLUSTER_ID="<Zeebe cluster Id>" \
    -e CAMUNDA_CLUSTER_REGION="<Zeebe region>" \
    -e PROJECT_TAG="<The tag of the resources to deploy>"
        bp3global/wm-extract-deploy:latest deploy
```

# Suppported Environment Variables

| EnvVar                   | Description                                                                                                    | Optional?                                                                                                                           |
|--------------------------|----------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| CAMUNDA_WM_CLIENT_ID     | The client Id of the Web Modeller client credentials                                                           | Required if performing the "extract" operation                                                                                      |
| CAMUNDA_WM_CLIENT_SECRET | The client secret of the Web Modeller client credentials                                                       | Required if performing the "extract" operation                                                                                      |
| GIT_USERNAME             | The Git user name used for committing extracted Web Modeller files                                             | Required if performing the "extract" operation                                                                                      |
| GIT_EMAIL                | The Git email address used for committing extracted Web Modeller files                                         | Required if performing the "extract" operation                                                                                      |
| SKIP_CI                  | Indicates if upon commit, we do or do not want any pipelines to be executed. The options are "true" or "false" | Required if performing the "extract" operation                                                                                      |
| CAMUNDA_WM_PROJECT       | The name given to the Web Modeller Project that is to be extracted                                             | Optional for the "extract" operation. If not provided then the project Id from `wm-project-id` file in the repository will be used) |
| CICD_REPOSITORY_PATH     | The project namespace with the project name included                                                           | Required if performing the "extract" or "tag" operations                                                                            |
| CICD_ACCESS_TOKEN        | The access token issued that provides permissions for remote Git operations                                    | Required if performing the "extract" or "tag" operations                                                                            |
| CICD_PLATFORM            | Indicates which CI/CD platform is being used, with the supported options of "gitlab", "github" or "bitbucket"  | Required if performing the "extract" or "tag" operations                                                                            |
| CICD_SERVER_HOST         | The GitLab server host                                                                                         | Optional for the "extract" or "tag" operations. If using an on-premise GitLab, otherwise defaults to "gitlab.com"                   |
| PROJECT_TAG              | The label given to the tags created and also the tag that is checked out and deploy                            | Required if performing the "tag" or "deploy" operations                                                                             |
| CAMUNDA_CLUSTER_ID       | The Id of the Camunda SaaS cluster                                                                             | Required if performing the "deploy" operation                                                                                       |
| CAMUNDA_CLUSTER_REGION   | The region code the cluster is running in                                                                      | Required if performing the "deploy" operation                                                                                       |
| ZEEBE_CLIENT_ID          | The client Id of the Zeebe client credentials                                                                  | Required if performing the "deploy" operation                                                                                       |
| ZEEBE_CLIENT_SECRET      | The client secret of the Zeebe client credentials                                                              | Required if performing the "deploy" operation                                                                                       |

# Python runtime version issue
Currently, Python 3.11 is used as the base image - even though there are later versions of python available (at time of writing 3.12 is available).

When we try with python versions greater than 3.11 then the “deploy” operation fails with the following error message. As you can see the error is actually in the `pyzeebe` client even though we are using the latest version. Once the underlying error in `pyzeebe` is resolved, then we should be able to support a more up-to-date version of python.

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
