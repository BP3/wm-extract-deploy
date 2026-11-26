# WMED (Web Modeler Extract Deploy)

CI/CD tooling that moves Camunda 8 assets between Web Modeler, source control and a Zeebe cluster. It ships as a
Docker image (`ghcr.io/bp3/wm-extract-deploy`) that customers run in their own pipelines. User docs are in the
GitHub wiki, not this repo.

## Current direction

Read [docs/direction.md](docs/direction.md) before proposing changes to deploy or extract. In short: extract stays
(some customers have no source control, so GitSync is no use to them) but gets maintenance only, deploy is the
priority, WMED deploys what is in the working tree (no tag checkout), deploy will
offer a Web Modeler compatible atomic mode and a changed-only mode, and a move from gRPC to REST is likely.

## How it runs

- Entry point: `docker-entrypoint.sh` → `scripts/extractDeploy.sh <mode>` → `scripts/<mode>.sh` → `python/<mode>.py`.
  Modes are `extract`, `deploy` and `deploy templates`.
- If `CI` is set, the entrypoint just execs a shell, because GitLab pipes the job script into it.
- Configuration comes from environment variables. Each option is declared once with `configargparse` (`env_var=`),
  and shared options live in `ModelAction.parser` and `OAuth2.parser`. Keep the deprecated aliases working
  (see `Deployment.add_deprecated_options`).
- The Dockerfile copies `python/*.py` into `/app/scripts/` next to the shell scripts. That's why the scripts call
  `python "${SCRIPT_DIR}"/deploy.py`, and why `scripts/*.sh` don't work directly from a checkout.
- `NO_GIT`, `NO_GIT_FETCH` and `NO_GIT_SETUP` skip the git steps in the shell scripts.
- Deploy talks to Zeebe over gRPC via `pyzeebe`. Moving to the 8.8+ REST API is open (issue #94).

## Running locally

- Python: use a virtualenv and `pip install -r requirements.txt`. The image uses Python 3.13; pyzeebe needs 3.9 or
  later.
- To test deploy behaviour, a single `camunda/camunda:<version>` container is enough (gRPC on 26500). If the API
  rejects calls, set `CAMUNDA_SECURITY_AUTHENTICATION_UNPROTECTEDAPI=true`. Then run `python/deploy.py` with
  `CLUSTER_HOST=localhost` and `MODEL_PATH=<dir>`.
- The full compose stacks (`docker-compose.yaml`, `deploy-compose.yaml`, `extract-compose.yaml`) are only needed
  for extract, Web Modeler or identity. Their image versions are in `.env` and come from `ghcr.io/bp3`, which
  needs `docker login ghcr.io`.
- The images in `ghcr.io/bp3` are mirrored from their upstream sources with every platform, so the stacks run
  natively on Apple Silicon as well as on the amd64 CI runners. When a version in `.env` or `.env-8.8` changes,
  re-mirror with `tools/sync-images-to-ghcr.sh` (`DRY_RUN=true` first; it needs `GHCR_PAT` with `write:packages`,
  `GITHUB_USERNAME`, and `docker login` to Docker Hub to avoid its rate limit). Docker keeps images it has already
  pulled, so after a re-mirror run `docker compose -f <file> pull` to replace them.
- The Camunda 8.8 stacks (#123) have their versions in `.env-8.8` (used with `docker compose --env-file .env-8.8`).
  Until their compose files exist, the sync script reads their images from `tools/images-8.8.txt`; 8.8 compose files
  are named `*-8.8-compose.yaml` so the script reads them with `.env-8.8`. Camunda's Keycloak (used from 8.8) is
  mirrored as `camunda-keycloak`, since `keycloak` is Bitnami's.
- Always use `docker compose` (the plugin). GitHub's Ubuntu 26.04 runners don't have the standalone `docker-compose`.

## Integration tests

- Shell based, in `integration-tests/`. Run from the repo root against a built image tag:

  ```bash
  docker build -t ghcr.io/bp3/wm-extract-deploy:local .
  integration-tests/test-runner.sh local deploy-compose.yaml
  ```

- To run the same tests against WMED from the checkout instead of an image, set `WMED_RUN=local` with a Python 3.10+
  virtualenv (with `requirements.txt`) activated. The image tag argument is then ignored:

  ```bash
  WMED_RUN=local integration-tests/test-runner.sh local deploy-compose.yaml
  ```

  Local mode runs as you rather than `bp3user`, with your git and Python. CI's test job always uses image mode; its
  coverage job uses local mode (below).
- To measure the coverage of WMED's Python code, add `WMED_COVERAGE=true` to a local-mode run, with
  `requirements-test.txt` installed too. The runner reports it at the end and writes an HTML report to
  `integration-tests/coverage/html/`. The data accumulates across runs, so running both suites gives their combined
  coverage; delete `integration-tests/coverage/` to start again. Shell scripts aren't measured, and the figures are a
  guide to what's untested, not a target.
- Tests run WMED only through `run_wmed <work dir> <mode>` (in `core-functions.sh`), with its settings as `VAR=value`
  lines on stdin. It copies the work dir into the container and back in image mode, or runs `scripts/*.sh` from a
  temporary folder of links to `scripts/` and `python/` in local mode, and returns WMED's exit code.
- `test-runner.sh` brings the compose stack up and down around each `tests/<mode>*.sh`, waits until the services
  respond (`STACK_WAIT_SECONDS`, default 300 per service), and exits non-zero if any test fails. Each test follows
  the `_setup` / `Given` / `When` / `Then` / `_teardown` template in the existing tests.
- Tests run with `set -e`, so any failing command fails the test. Call `run_wmed` with `|| rc=$?` and check the code
  with `assert_success` (or `assert_equals` for an expected failure). Quote arguments to `assert_equals`. Operate shows a deployment a few seconds after it happens, so
  use `wait_for_process_definition` rather than searching once. Helpers are in `core-functions.sh`,
  `deploy-functions.sh` and `extract-functions.sh`.
- On the 8.7 stack, Operate shows processes and decisions, but nothing shows forms, so deploy tests read Zeebe's
  Elasticsearch exporter records (`zeebe-record_form_*`, `zeebe-record_deployment_*` on port 9200) for forms and for
  what went into a deployment. They're internal records, not an API: move these checks to `/v2` with Camunda 8.8+.
- The stacks keep their data between runs (`docker compose down` keeps the volumes), so a check can pass on an earlier
  run's deployment. Note the latest deployment before deploying and wait for a newer one
  (`latest_deployment_key_with_process`, `wait_for_deployment_with_process`), as `deploy-resource-types.sh` does.
- Needs `jq`, `yq` (mikefarah's) and `xmllint` on the host.
- CI (`.github/workflows/branch-build.yaml`) builds the branch image, then runs the extract and deploy suites. It
  runs on pull requests (and manually), not on a plain push. Alongside, the `measure-coverage` job runs both suites in
  local mode with `WMED_COVERAGE=true`, writes the coverage table to the run's summary page, uploads the HTML report as
  the `coverage-html` artifact, and comments the figures on the PR (`orgoro/coverage`). It fails if a test fails, or
  if overall coverage is below 60% (`thresholdAll` in the workflow; a starting point, to review as the tests grow). The PR comment step
  applies it, so it's only enforced on pull requests.
- The testing plan (order of the testing work before the deploy refactoring) is kept outside the repo, as the
  "WMED Testing Plan" page.

## Zeebe deploy behaviour (tested on 8.7.5 and 8.10.7, Nov 2026)

These shape the deploy design. Re-check them on new Camunda versions rather than assuming.

- **Duplicate detection covers the whole deployment.** Re-deploying an identical set creates no new versions, but if
  any resource in a multi-resource deployment changed, *every* resource in it gets a new version.
- Comparison is on raw bytes plus resource name. pyzeebe uses the file's basename as the name, so a whitespace-only
  change or a rename creates a new version. Re-deploying older content creates a new latest version.
- A rejected deployment lists the errors for every invalid resource, and nothing in it is deployed.
- `bindingType="deployment"` (call activities, business rule tasks, linked forms): 8.10 rejects the deployment
  unless the target is in the same deployment, even if it already exists on the cluster. 8.7 doesn't check.
- Files with the same basename in different directories can go in one deployment.

## Conventions

- Python, shell and Dockerfile sources start with the BP3 licence header block (compose and workflow YAML don't);
  copy it from an existing file and use the current year for new files.
- Shell scripts are POSIX `sh` (the image is Alpine), not bash.
- Match the existing style: logging via `self.logger`, options declared next to the class that uses them.
