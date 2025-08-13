# Extract and Deploy process models from Web Modeler
## Background
Web Modeler does not currently have support for the extraction and deployment of resources (i.e., BPMN, DMN and Forms)
to different CI / CD platforms such as GitLab, GitHub and Bitbucket — the user must manage this through the [WM API](https://docs.camunda.io/docs/apis-tools/web-modeler-api/overview/).
The Web Modeler currently only has
* An option to deploy models directly to a Zeebe cluster (subject to the user having the right roles assigned)
* A native GitHub integration to allow users to synch the models to a repository (again, subject to the user having the right roles assigned)

## Solution
This project provides solutions to:
* Extract models from Web Modeler using the Web Modeler API, and
* Update a git repo with the extracted model
* Deploy a tagged version of the model to a target Zeebe cluster (environment)

To facilitate that, a Docker image is provided that is capable of 
those operations and is suited for use in a DevOps pipeline. 
The operations work with any CI/CD platform and have so far been tested with:
* [GitLab](./GitLab.md)
* [Github](./Github.md)
* [Bitbucket](./BitBucket.md)

Use the links above to understand how to integrate the extract and deploy operations into your
DevOps pipelines.

# Running the Docker container
The container can be run in the following modes, as described below:

## Extract
To extract process models from a Web Modeler project and commit to a local git repository:

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

For Self-Managed environments:
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

For Self-Managed deployments:
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
This will deploy connector templates from the current repo/directory and its subdirectories into the Web Modeler instance and then commit the configuration file to the repository.

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

For Self-Managed environments:
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

The configuration file can be either YAML or JSON and by default we will look for a file named `config.[yml|yaml|json]` in the working directory. If you wish to use an alternate name, then this can be specified in the `WM_PROJECT_METADATA_FILE` environment variable. If a config file is not detected, then one will be created after the first successful execution. 

The config file should contain a project element with a child id element where the value is the id of the project in Web Modeler (the guid in the URL when accessing the project), and optionally a name property.

e.g. in YAML:
```yaml
project:
  id: 571c8e5d-dcdf-41b5-bb42-e5f3ae593db9
  name: Connector Templates
```

# Supported Environment Variables

| EnvVar                      | Description                                                                                                                                                                                                        | Optional?                                                                                                                                               |
|-----------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| `CAMUNDA_WM_CLIENT_ID`      | _Deprecated:_ see `OAUTH2_CLIENT_ID`                                                                                                                                                                               |                                                                                                                                                         |
| `CAMUNDA_WM_CLIENT_SECRET`  | _Deprecated:_ see `OAUTH2_CLIENT_SECRET`                                                                                                                                                                           |                                                                                                                                                         |
| `CAMUNDA_WM_HOST`           | The hostname of the Web Modeler installation                                                                                                                                                                       | Optional (default = `cloud.camunda.io`)                                                                                                                 |
| `CAMUNDA_WM_PROJECT`        | The name given to the Web Modeler Project that is to be extracted                                                                                                                                                  | Optional for "extract" operation. If not provided then the project Id from `wm-project-id` file in the repository will be used                          |
| `CAMUNDA_WM_SSL`            | Whether to use an SSL connection or not                                                                                                                                                                            | Optional (default = `true`)                                                                                                                             |
| `CICD_ACCESS_TOKEN`         | The access token issued that provides permissions for remote Git operations                                                                                                                                        | Required for "extract" operation                                                                                                                        |
| `CICD_BRANCH`               | The branch that the extracted model should be committed to                                                                                                                                                         | Optional (default = `main`)                                                                                                                             |
| `CICD_PLATFORM`             | Indicates which CI/CD platform is being used, with the supported options of "gitlab", "github" or "bitbucket"                                                                                                      | Required for "extract" operation                                                                                                                        |
| `CICD_REPOSITORY_PATH`      | The project namespace with the project name included                                                                                                                                                               | Required for "extract" operation                                                                                                                        |
| `CICD_SERVER_HOST`          | The GitLab server host                                                                                                                                                                                             | Optional for "extract" operation. For on-premise GitLab, otherwise defaults to "gitlab.com"                                                             |
| `COMMIT_MSG`                | The message applied to the extract commit                                                                                                                                                                          | Optional (default = `Updated by Camunda extract-deploy pipeline`)                                                                                       |
| `CONTINUE_ON_ERROR`         | Don't stop deployment if resources have errors. By default a deployment is atomic and it eiter all succeeds or nothing is deployed, this allows for some to fail deployment, but those that are valid are deployed | Optional for "deploy" operation                                                                                                                         |
| `EXCLUDE`                   | [RegEx pattern](https://docs.python.org/3/howto/regex.html) of path segments to exclude from extraction (Default: `wmedIgnore`)                                                                                    | Optional for "extract" operation                                                                                                                        |
| `GIT_EMAIL`                 | The Git email address used for committing extracted Web Modeler files                                                                                                                                              | Required for "extract" operation                                                                                                                        |
| `GIT_USERNAME`              | The Git user name used for committing extracted Web Modeler files                                                                                                                                                  | Required for "extract" operation                                                                                                                        |
| `NO_GIT_FETCH`              | Specify `TRUE` to skip git fetch when deploying                                                                                                                                                                    | Required when running deploy.sh in AWS CodeDeploy                                                                                                       |
| `MODEL_PATH`                | The directory that "extract" will write the extracted files to                                                                                                                                                     | Optional (default=`model`)                                                                                                                              |
| `PROJECT_TAG`               | The label given to the tags created and also the tag that is checked out and deployed                                                                                                                              | Required for "deploy" operation                                                                                                                         |
| `OAUTH2_AUDIENCE`           | The OAuth2 Audience                                                                                                                                                                                                | Optional, use if needed for your identity/authentication provider                                                                                       |
| `OAUTH2_CLIENT_ID`          | The OAuth2 Client Id                                                                                                                                                                                               | Required for "extract" (Web modeler read access) and "deploy" (Zeebe write access), and "deployTemplates" (Web Modeler write/update access)             |
| `OAUTH2_CLIENT_SECRET`      | The OAuth2 Client Secret                                                                                                                                                                                           | Required for "extract"  (Web modeler read access), "deploy" (Zeebe write access), and "deployTemplates" (Web Modeler write/update access)               |
| `OAUTH2_GRANT_TYPE`         | The OAuth2 Grant type                                                                                                                                                                                              | Optional, defaults to `client_credentials`, change if needed for your identity/authentication provider                                                  |
| `OAUTH2_SCOPE`              | The OAuth2 Scope                                                                                                                                                                                                   | Optional, use if needed for your identity/authentication provider                                                                                       |
| `OAUTH2_TOKEN_URL`          | The authentication endpoint URL for retrieving the OAuth2 token                                                                                                                                                    | Required for Self managed web modeler and Zeebe operations                                                                                              |
| `OAUTH_PLATFORM`            | _Deprecated:_ The OAuth2 platform in use                                                                                                                                                                           | Optional (default = KEYCLOAK, supported values: KEYCLOAK, ENTRA)                                                                                        |
| `SKIP_CI`                   | Indicates if upon commit, we do or do not want any pipelines to be executed. The options are "true" or "false"                                                                                                     | Required for "extract" operation                                                                                                                        |
| `WM_PROJECT_METADATA_FILE`  | The name of the web modeller project configuration file                                                                                                                                                            | Optional for operations involving web modeler (If not present, will look for`config.yml/yaml/json`)                                                     |
| `ZEEBE_CLIENT_ID`           | Deprecated: see `OAUTH2_CLIENT_ID`                                                                                                                                                                                 |                                                                                                                                                         |
| `ZEEBE_CLIENT_SECRET`       | Deprecated: see `OAUTH2_CLIENT_SECRET`                                                                                                                                                                             |                                                                                                                                                         |
| `ZEEBE_CLUSTER_HOST`        | The hostname or IP of the Camunda cluster gateway                                                                                                                                                                  | Required for "deploy" operation in Self managed environments                                                                                            |
| `ZEEBE_CLUSTER_ID`          | The Id of the Camunda SaaS cluster                                                                                                                                                                                 | Required for "deploy" operation in SaaS environments                                                                                                    |
| `ZEEBE_CLUSTER_PORT`        | The port number of the Camunda cluster gateway                                                                                                                                                                     | Optional for "deploy" operation in Self managed environments (default = `26500`)                                                                        |
| `ZEEBE_CLUSTER_REGION`      | The region code the cluster is running in                                                                                                                                                                          | Required for "deploy" operation in SaaS environments                                                                                                    |
| `ZEEBE_TENANT_IDS`          | A comma seperated list of the tenant id(s) to deploy to for multi-tenant environments                                                                                                                              | Optional for "deploy" operations (default no tenants)                                                                                                   |

# Using a local Zeebe docker stack for development
## Docker and hostnames
If you are running the extract/deploy app on the same host as the Zeebe docker stack (i.e. on a developer's computer)
you need to make some changes to the Docker compose file for the Zeebe stack in order for the authentication to work
between the local containers, or your will get `An error occurred while attempting to decode the Jwt: The iss claim is not valid`

Assuming that you are using the docker compose files from [this repo](https://github.com/camunda/camunda-platform); In the directory with the Camunda 8
docker-compose file you should edit the `.env` file and change the `HOST` variable from `localhost` to your hosts IP address.

The Web Modeler docker compose does not use these environment variables, so we need to update them individually.
Open the `docker-compose-web-modeler.yaml` file in a text editor and update the following environment
variable lines, replacing `localhost` in the URLs with `${HOST}` while leaving the port number intact:

- RESTAPI_OAUTH2_TOKEN_ISSUER
- RESTAPI_SERVER_URL
- SERVER_URL
- OAUTH2_TOKEN_ISSUER

Save the changes and then create the docker container as usual. You will need to use your IP address rather than
`localhost` when accessing any of the exposed services (i.e. Operate, Web Modeler etc.) but otherwise they should function as normal.

## Authentication setup

### Extraction from and Connector Template Deployment to Web Modeler
You need to create a client app and secret for the extract-deploy app to use for accessing Web Modeler.
1. Open Identity in your browser https://localhost:8084 and log in.
2. Click **Add Application**, enter a name, like `wm-extract-deploy` (use this as the Client ID), select the **M2M** radio button, and click **Add**.
3. Click on the new Application you created and make a note of the Client Secret as you will need this for the extract script.
4. Open the **Access to APIs** tab, click the **Assign Permissions** button and then select **Web Modeler API** from the dropdown. Select the read, write, and create permission checkboxes and then click the **Add** button.

### Deployment to Zeebe
You can use the standard client id: `zeebe` and client secret: `zecret`, or add 

## Building locally

`docker build -t bp3global/wm-extract-deploy .`

See (TESTING.md)
