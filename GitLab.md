# Pipeline examples for GitLab
This page shows an example GitLab pipeline `gitlab-ci.yml` file that can be used to execute stages for extraction and deployment for the following installation types:

1. SaaS: Web Modeler and Zeebe Cluster
2. Self-Managed: Web Modeler and Zeebe Cluster
3. docker-compose: Web Modeler and Zeebe Cluster

The example `gitlab-ci.yml` file in this page is for SaaS, but the exact same structure can be used for Self-Managed and Docker Compose installs, 
adjusting the environment variables to suit as detailed in [README.md](./README.md#supported-environment-variables).

## Variables
It is best practice is to have many of the environment variables that are required, pre-defined.
Commonly these will be added as CI / CD variables defined at group level, so that they can be re-used across a
wide range of projects. In the example below the following variables are assumed to have
been defined at the group level and so are simply re-used as shown.

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

## `gitlab-ci.yml`
Below is an example on how the Docker image could be used when defining the pipeline configuration. It shows two stages, 'extract' and 'deploy', that are executed based on the state of the `MODE` and `DEPLOY_TAG` environment variables.

```yaml
image: bp3global/wm-extract-deploy

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
