# Extract, Tag and Deploy process models from Web Modeler
This is a project to explore some ideas around using a pipeline to 

* Extract models from Web Modeler using the Web Modeler API
* Update a git repo with the extracted model
* Deploy a tagged version of the model to another environment

To facilitate those operations we will create a Docker image that is easily capable of 
those operations and that is suited for use in a pipeline.

## Background
Unfortunately although Web Modeler is able to deploy models to clusters where the user
has access rights the way it works doesn't scale well and is certainly not robust for
Enterprise use. Neither does Web Modeler manage version control well for the time being.
Whilst that will likely improve in the future, for now, the advice from Camunda is still to use
an external tool for version control - in practice that will generally mean `git`.

# Building the Docker image
The docker image is based on python which we are using as the underlying scripting language -
simply because it is widely used and well supported with libraries. Specifically the
Camunda `pyzeebe` library which we use to deploy the extracted models to a Zeebe cluster.

To build the Docker image, run the following command:

```shell
docker build -t camunda-extract-deploy .
```

# Running the Docker container
The container can be run in three modes, as described below:

## Extract
To extract process models from Web Modeler project to a local `git` repository:

```shell
docker run -it --rm \
    --mount type=bind,src=${PWD},dst=/local \
    --workdir /local -e PROJECT_PATH=/local \
    -e CAMUNDA_WM_CLIENT_ID="<Client Id>" \
    -e CAMUNDA_WM_CLIENT_SECRET="<Client secret>" \
    -e CAMUNDA_WM_PROJECT="<The WM project to extract from>" \
    -e GIT_USERNAME="<Git Username>" \
    -e GIT_USER_EMAIL="<Git Email address>" \
    -e CI_SERVER_HOST="<The host of the GIT server>" \
    -e GROUP_ACCESS_TOKEN="<Git Group Access Token>" \
    -e CI_PROJECT_PATH="<The project namespace with the project name included>" \
        camunda-extract-deploy extract
```

## Tag
This will tag the tip of the specified branch:

```shell
docker run -it --rm \
    --mount type=bind,src=${PWD},dst=/local \
    --workdir /local -e PROJECT_PATH=/local \
    -e CI_SERVER_HOST="<The host of the GIT server>" \
    -e GROUP_ACCESS_TOKEN="<Git Group Access Token>" \
    -e PROJECT_TAG="<The tag to create>" \
    -e CI_PROJECT_PATH="<The project namespace with the project name included>" \
        camunda-extract-deploy tag
```

# Deploy
This will deploy the tagged commit to the target Zeebe cluster:

```shell
docker run -it --rm \
    --mount type=bind,src=${PWD},dst=/local \
    --workdir /local -e PROJECT_PATH=/local \
    -e CAMUNDA_ZEEBE_CLIENT_ID="<Zeebe client Id>" \
    -e CAMUNDA_ZEEBE_CLIENT_SECRET="<Zeebe client secret>" \
    -e CAMUNDA_CLUSTER_ID="<Zeebe cluster Id>" \
    -e CAMUNDA_REGION="<Zeebe region>" \
    -e DEPLOY_FROM_TAG="<The tag of the resources to deploy>"
        camunda-extract-deploy deploy
```

# Suppported Environment Variables

| EnvVar                      | Description                                   |
|-----------------------------|-----------------------------------------------|
| CAMUNDA_CLUSTER_ID          |  |
| CAMUNDA_REGION              |  |
| CAMUNDA_WM_CLIENT_ID        |  |
| CAMUNDA_WM_CLIENT_SECRET    |  |
| CAMUNDA_WM_PROJECT          |  |
| CAMUNDA_ZEEBE_CLIENT_ID     |  |
| CAMUNDA_ZEEBE_CLIENT_SECRET |  |
| DEPLOY_FROM_TAG             |  |
| PROJECT_TAG                 |  |
| CI_SERVER_HOST              |  |
| GIT_USERNAME                |  |
| GIT_EMAIL                   |  |
| CI_PROJECT_PATH             |  |
| GROUP_ACCESS_TOKEN          |  |
