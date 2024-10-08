# Pipeline examples for GitLab
Below you will see examples for a number of scenarios

1. SaaS: Web Modeler and Zeebe Cluster
1. Self-Managed: Web Modeler and Zeebe Cluster 
1. docker-compose: Web Modeler and Zeebe Cluster

Best practice is to have many of the environment variables that are required pre-defined.
Commonly these will be added as group variables so that they can be re-used across a
wide range of projects. In the examples below the following variables are assumed to have
been defined at the group level and so are simply re-used as shown

![GitLab CI/CD environment variable configuration](images/gl-cicd-env-vars.png)

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
Below is an example on how the Docker image could be used when defining the pipeline configuration. It shows two stages, 'extract' and 'deploy', that are executed based on the state of the `MODE` and `DEPLOY_TAG` environment variables.

```yaml
image: bp3global/wm-extract-deploy:0.1.0

variables:
  CICD_PLATFORM: gitlab
  CICD_SERVER_HOST: $CI_SERVER_HOST
  CICD_ACCESS_TOKEN: $BUILD_ACCOUNT_ACCESS_TOKEN
  CICD_REPOSITORY_PATH: $CI_PROJECT_PATH

stages:
  - extract
  - deploy

extract-artifacts-from-modeler:
  stage: extract
  rules:
    - if: $MODE == "extract"
      when: always
  variables:
    CAMUNDA_WM_CLIENT_ID: $CAMUNDA_WM_CLIENT_ID
    CAMUNDA_WM_CLIENT_SECRET: $CAMUNDA_WM_CLIENT_SECRET
    CAMUNDA_WM_PROJECT: $CAMUNDA_WM_PROJECT
    CAMUNDA_CLUSTER_ID: $CAMUNDA_CLUSTER_ID
    CAMUNDA_CLUSTER_REGION: $CAMUNDA_CLUSTER_REGION
    GIT_USERNAME: $BUILD_ACCOUNT_USER
    GIT_USER_EMAIL: $BUILD_ACCOUNT_EMAIL
    SKIP_CI: true
  script:
    /scripts/extractDeploy.sh extract

deploy-modeler-artifacts-to-zeebe:
  stage: deploy
  rules:
    - if: $MODE == "deploy" && $DEPLOY_TAG != null && $DEPLOY_TAG != ""
      when: always
  variables:
    ZEEBE_CLIENT_ID: $CAMUNDA_ZEEBE_CLIENT_ID
    ZEEBE_CLIENT_SECRET: $CAMUNDA_ZEEBE_CLIENT_SECRET
    CAMUNDA_CLUSTER_ID: $CAMUNDA_ZEEBE_CLUSTER_ID
    CAMUNDA_CLUSTER_REGION: $CAMUNDA_CLUSTER_REGION
    PROJECT_TAG: $DEPLOY_TAG
  script:
    /scripts/extractDeploy.sh deploy
```

## Scenario 2: Self-Managed
```yaml
image: bp3global/wm-extract-deploy:0.1.0

variables:
  CICD_PLATFORM: gitlab
  CICD_SERVER_HOST: $CI_SERVER_HOST
  CICD_ACCESS_TOKEN: $BUILD_ACCOUNT_ACCESS_TOKEN
  CICD_REPOSITORY_PATH: $CI_PROJECT_PATH

stages:
  - extract
  - deploy

extract-artifacts-from-modeler:
  stage: extract
  rules:
    - if: $MODE == "extract"
      when: always
  variables:
    CAMUNDA_WM_CLIENT_ID: $CAMUNDA_WM_CLIENT_ID
    CAMUNDA_WM_CLIENT_SECRET: $CAMUNDA_WM_CLIENT_SECRET
    CAMUNDA_WM_PROJECT: $CAMUNDA_WM_PROJECT
    CAMUNDA_CLUSTER_ID: $CAMUNDA_CLUSTER_ID
    CAMUNDA_CLUSTER_REGION: $CAMUNDA_CLUSTER_REGION
    GIT_USERNAME: $BUILD_ACCOUNT_USER
    GIT_USER_EMAIL: $BUILD_ACCOUNT_EMAIL
    SKIP_CI: true
  script:
    /scripts/extractDeploy.sh extract

deploy-modeler-artifacts-to-zeebe:
  stage: deploy
  rules:
    - if: $MODE == "deploy" && $DEPLOY_TAG != null && $DEPLOY_TAG != ""
      when: always
  variables:
    ZEEBE_CLIENT_ID: $CAMUNDA_ZEEBE_CLIENT_ID
    ZEEBE_CLIENT_SECRET: $CAMUNDA_ZEEBE_CLIENT_SECRET
    CAMUNDA_CLUSTER_HOST: $CAMUNDA_CLUSTER_HOST
    CAMUNDA_CLUSTER_PORT: $CAMUNDA_CLUSTER_PORT
    PROJECT_TAG: $DEPLOY_TAG
  script:
    /scripts/extractDeploy.sh deploy
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
