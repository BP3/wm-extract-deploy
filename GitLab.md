# Pipeline examples for GitLab
Below you will see examples for a number of scenarios

1. SaaS: Web Modeler and Zeebe Cluster
1. Self-Managed: Web Modeler and Zeebe Cluster 
1. docker-compose: Web Modeler and Zeebe Cluster

Best practice is to have many of the environment variables that are required pre-defined.
Commonly these will be added as group variables so that they can be re-used across a
wide range of projects. In the examples below the following variables are assumed to have
been defined at the group level and so are simply re-used as shown

* `CAMUNDA_SAAS_USERID`, `CAMUNDA_SAAS_USERPWD`
* `CAMUNDA_ZEEBE_CLIENT_ID`, `CAMUNDA_ZEEBE_CLIENT_SECRET`
* `CAMUNDA_ZEEBE_CLUSTER_ID`, `CAMUNDA_ZEEBE_CLUSTER_REGION`
* `CAMUNDA_ZEEBE_CLUSTER_HOST`, `CAMUNDA_ZEEBE_CLUSTER_PORT`

## Scenario 1: SaaS

* SaaS Web Modeler with a project called `xxyyzz`
* GitLab repo `repo-name`
   * Repo has a file `config.json` in the root directory that contains at least the Id of the WM project


```json
{
  "project": {
    "id": "<UUID>",
    "name": "xxyyzz"
  }
}
```

### `gitlab-ci.yml`
ToDo
* Need to check that we have the right system variables here
* For deploy then how do we select variables per environment

```yaml
image: bp3global/wm-extract-deploy

variables:
  CICD_PLATFORM: gitlab
  CICD_SERVER_HOST: $CI_SERVER_HOST
  CICD_ACCESS_TOKEN: $BUILD_ACCOUNT_ACCESS_TOKEN
  CICD_REPOSITORY_PATH: $CI_CONFIG_PATH

# https://stackoverflow.com/questions/65214169/set-ci-cd-variables-depending-on-environment
.set-variables-dev:
  variables:
    TOKEN: $DEV_TOKEN
.set-variables-prod:
  variables:
    TOKEN: $PROD_TOKEN
    
job-dev:
  environment: DEV
  extends:
    .set-variables-dev
job-prod:
  environment: PROD
  extends:
    .set-variables-prod

###############################
stages:
  - extract
  - deploy

extract-artifacts-from-modeler:
  stage: extract
  variables:
    CAMUNDA_WM_CLIENT_ID: $CAMUNDA_SAAS_USERID
    CAMUNDA_WM_CLIENT_SECRET: $CAMUNDA_SAAS_USERPWD
    GIT_USERNAME: $BUILD_ACCOUNT
    GIT_USER_EMAIL: $BUILD_ACCOUNT_EMAIL
    SKIP_CI: true
  script:
    extract

deploy-modeler-artifacts-to-zeebe:
  stage: deploy
  variables:
    ZEEBE_CLIENT_ID: $CAMUNDA_ZEEBE_CLIENT_ID
    ZEEBE_CLIENT_SECRET: $CAMUNDA_ZEEBE_CLIENT_SECRET
    CAMUNDA_CLUSTER_ID: $CAMUNDA_ZEEBE_CLUSTER_ID
    CAMUNDA_CLUSTER_REGION: $CAMUNDA_CLUSTER_REGION
    PROJECT_TAG: $DEPLOY_TAG
  script:
    deploy
```

## Scenario 2: Self-Managed
```yaml
image: bp3global/wm-extract-deploy

variables:
  CICD_PLATFORM: gitlab
  CICD_SERVER_HOST: $CI_SERVER_HOST
  CICD_ACCESS_TOKEN: $BUILD_ACCOUNT_ACCESS_TOKEN
  CICD_REPOSITORY_PATH: $CI_CONFIG_PATH

stages:
  - extract
  - deploy

extract-artifacts-from-modeler:
  stage: extract
  variables:
  script:
    extract
  
deploy-modeler-artifacts-to-zeebe:
  stage: deploy
  variables:
    ZEEBE_CLIENT_ID: $CAMUNDA_ZEEBE_CLIENT_ID
    ZEEBE_CLIENT_SECRET: $CAMUNDA_ZEEBE_CLIENT_SECRET
    CAMUNDA_CLUSTER_HOST: $CAMUNDA_ZEEBE_CLUSTER_HOST
    CAMUNDA_CLUSTER_PORT: $CAMUNDA_ZEEBE_CLUSTER_PORT
    PROJECT_TAG: $DEPLOY_TAG
  script: 
    deploy
```

## Scenario 3: docker-compose
```yaml
image: bp3global/wm-extract-deploy

variables:
  CICD_PLATFORM: gitlab
  CICD_SERVER_HOST: $CI_SERVER_HOST
  CICD_ACCESS_TOKEN: $BUILD_ACCOUNT_ACCESS_TOKEN
  CICD_REPOSITORY_PATH: $CI_CONFIG_PATH

stages:
   - extract
   - deploy

extract-artifacts-from-modeler:
  stage: extract
  variables:
  script:
    extract
  
deploy-modeler-artifacts-to-zeebe:
  stage: deploy
  variables:
  script: 
    deploy
```
