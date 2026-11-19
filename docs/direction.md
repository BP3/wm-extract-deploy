# WMED direction

Where WMED is heading and why. This records decisions and the reasoning behind them, so they don't get lost between
bursts of work. Update it when a decision changes; add the date and a line on what changed.

*Started November 2026, when work on WMED resumed after a long pause.*

## Background

WMED was built to fill a gap in the Camunda 8 toolchain between Web Modeler and source control: extract models
from Web Modeler into git, and deploy them from git to a cluster.

Two things stalled it:

- Camunda released **GitSync** in Web Modeler, which covers the export side.
- The deploy requirements became too ambitious, mainly the ability to deploy a specific tag or older version of
  the repository.

## Decisions

### 1. Extract stays, in maintenance; deploy is the priority

GitSync isn't perfect, but it is good enough, and because it comes with the product it is what most users with
source control will choose. Extract gets maintenance only: no new features, and we fix what breaks.

*Updated 7 November 2026:* extract was going to enter a sunset period, but it has a use case GitSync can't cover.
A colleague has a customer with no source control at all, so GitSync is no use to them and WMED extract is
their only way to get models out of Web Modeler. That's unusual, but because such customers exist, extract should
be retained rather than phased out. Extract without git already works by setting `NO_GIT`, which writes the
files to `MODEL_PATH` without committing or pushing. Supporting this use case properly may need:

- deletions handled in `NO_GIT` mode: the `git rm` of existing models only happens in git mode, so models
  deleted in Web Modeler stay in the output directory
- documenting `NO_GIT` extract as a supported way of working
- an integration test for it (`extract-1.sh` already runs with `NO_GIT=true`)

Deploy is still a huge gap in the Camunda toolchain for customers using GitSync and then deploying from source control. This is still a good spot for WMED to make life simpler for customers.

### 2. Deploy what is in the repository

Drop the attempt to deploy specific tags or older versions. WMED deploys the files in the working tree it is given.
Selecting the revision is the CI pipeline's job; it already checks out the commit it is building.

In practice this means removing the `git fetch` / `checkout` of `PROJECT_TAG` / `CICD_BRANCH` from
`scripts/deploy.sh`.

### 3. Offer two deploy modes: Web Modeler compatible, and changed-only

**Web Modeler compatible (atomic, everything).** A Web Modeler project (previously "process application") is
deployed atomically: if any file is invalid, nothing is deployed. Users should be able to choose this mode easily
and get the same behaviour as Web Modeler.

Its drawback is that it creates new versions of files that haven't changed. Zeebe skips a deployment only when
*every* resource in it is unchanged, so one changed file re-versions the whole project. In strict configuration
management terms that may be right, but many users dislike it, and it makes process instance migration harder.

**Changed-only (hybrid).** Deploy only the files that have changed, but deploy that set atomically. This avoids the
unnecessary versions and keeps the all-or-nothing behaviour for what is deployed. The Camunda API doesn't do this
for us, so WMED has to:

1. For each local file, find its id (BPMN process id, DMN decision requirements id, form id) by reading the XML or
   JSON.
2. Look up the latest deployed version of that id on the cluster and download its content. As far as we know, the
   API doesn't expose a hash, so the content has to be downloaded.
3. Compare the bytes of the two. Both are in hand, so a direct comparison is simpler and faster than hashing them
   first, and it matches what Zeebe treats as changed (Zeebe compares raw bytes).
4. Deploy the changed files together in one atomic deployment.

A file whose id doesn't exist on the cluster yet counts as changed.

Comparing against the cluster rather than with `git diff` handles clusters that were also deployed to from Web
Modeler or elsewhere, and doesn't need WMED to remember what it last deployed.

The file-by-file mode (`CONTINUE_ON_ERROR`) doesn't match either of these. It allows partial deploys and exits 0
when files fail. The plan is to replace it rather than keep it as a third mode. Its main benefit, seeing every
broken file at once, is already provided by an atomic deploy, because Zeebe's rejection lists the errors for every
invalid file.

### 4. Seriously consider moving deploy from gRPC to REST

WMED is in Python because, when it started, gRPC was the only Zeebe protocol and pyzeebe was the only working client
in an interpreted language. Camunda 8.8 added the Orchestration Cluster REST API, which can deploy resources and also
provides the search and resource-content endpoints that changed-only mode needs. Moving to REST would:

- remove the dependency on pyzeebe and gRPC
- put deploy and change detection on the same API
- follow Camunda's direction, which is REST first

It also means Python is no longer required. That doesn't mean a rewrite, but it is no longer a constraint. See
issue #94.

### 5. Migrate WMED's project file to Camunda's project markers

*Added 14 November 2026.*

Today extract writes `config.yml` (name set by `WM_PROJECT_METADATA_FILE`) to the current working directory. It
holds the Web Modeler project's id and name, and is committed with the models. Camunda's tools now use their own
marker files instead, so WMED needs a migration path:

- **Before 8.10:** `.process-application`, the marker for a Web Modeler process application.
- **8.10 and later:** `camunda.json`, with the Camunda Hub project id in `hub.projectId`.

Points to design for:

- **`.process-application` carries no data.** It is an empty marker file (c8ctl treats an empty or whitespace-only
  file as valid), so it has nowhere to store the project id. Before 8.10, WMED still needs `config.yml` alongside
  it. From 8.10, `camunda.json` can hold the id and replace `config.yml`.
- **Location.** Markers belong in the project's root folder (`MODEL_PATH`, or the folder GitSync uses), whereas
  `config.yml` is written to the working directory. Migrating means moving it as well as renaming it.
- **Reading.** Look for the project id in `camunda.json` (`hub.projectId`) first, then `config.yml`, then
  `CAMUNDA_WM_PROJECT`, and keep reading `config.yml` for at least one release so existing repos keep working.
- **Writing.** Don't overwrite a marker that already exists, since GitSync or Desktop Modeler users may have created
  it. Add `hub.projectId` to an existing `camunda.json` only if it's missing, and keep any other fields. Write
  `camunda.json` rather than `.process-application` when both would apply, because it takes precedence.
- **Choosing which marker.** Either detect the Web Modeler / Camunda Hub version (the integration tests already
  call `/api/v1/info`) or make it an option.
- **Deploy benefits too.** If extract writes the markers, its output can be deployed one project at a time under the
  deployment unit proposal below.

To verify before building this:

- **What a pre-8.10 project becomes in 8.10.** Before 8.10, a Web Modeler project could contain several process
  applications. From 8.10, workspaces contain projects, and projects are the former process applications. WMED
  extracts a whole Web Modeler project, which may now correspond to a workspace containing several projects, each
  needing its own folder and marker. If so, this is more than a rename.
- **Whether the ids match.** Is the project id WMED stores the same id that `hub.projectId` expects?
- **Whether WMED's Web Modeler API calls (`/api/v1/...`) still work against Camunda Hub in 8.10.**

## Deprecation

*Added 18 November 2026.* Features and settings that the decisions above make candidates for deprecation. None has
been deprecated yet: this is a list to decide on, grouped by how firmly each one follows from the decisions.

### Follow from decisions already made

- **Deploy's git checkout (decision 2).** Once `scripts/deploy.sh` no longer fetches and checks out a ref,
  `PROJECT_TAG` and `CICD_BRANCH` have no effect on deploy, `NO_GIT` and `NO_GIT_FETCH` have nothing to skip there,
  and deploy no longer needs `GIT_USERNAME` or `GIT_USER_EMAIL`, because it never commits. Could be deprecated now,
  with a warning when they're set for deploy.
- **`CONTINUE_ON_ERROR` (decision 3).** File-by-file deploy allows partial deploys and exits 0 when files fail.
  Deprecate it once the Web Modeler compatible and changed-only modes exist to replace it.
- **`config.yml` and `WM_PROJECT_METADATA_FILE` (decision 5).** Deprecate once extract writes `camunda.json`, and
  keep reading `config.yml` for at least one release.

### Already deprecated, so candidates for removal

- **Old setting names:** `CAMUNDA_CLUSTER_*` and `ZEEBE_CLUSTER_*` (now `CLUSTER_ID`, `CLUSTER_HOST`,
  `CLUSTER_REGION`, `CLUSTER_PORT`), and `CAMUNDA_WM_CLIENT_*` and `ZEEBE_CLIENT_*` (now `OAUTH2_CLIENT_ID` and
  `OAUTH2_CLIENT_SECRET`). They're hidden from `--help` but still work. `CLAUDE.md` says to keep them working, so
  removing them means changing that and choosing the release they go in.
- **`OAUTH_PLATFORM`** (KEYCLOAK/ENTRA). Its help already says to use scope and audience instead.

### Depend on the open questions about REST and version support

- **gRPC connection settings.** `CLUSTER_PORT` (default 26500) is gRPC only, and `CLUSTER_ID` with `CLUSTER_REGION`
  is pyzeebe's SaaS connection. A REST client takes a single URL instead, as c8ctl does. If deploy moves to REST and
  supports 8.8+ only, these are replaced, and 8.7 users stay on the current release.
- **`ZEEBE_TENANT_IDS`.** The last setting with the `ZEEBE_` prefix. Rename it (to `TENANT_IDS`, say) and keep the
  old name as a deprecated alias, as the other renames did. Cosmetic.

### Need discussion

- **Extract's git mode** (commit and push, with `CICD_PLATFORM`, `CICD_ACCESS_TOKEN`, `CICD_REPOSITORY_PATH`,
  `CICD_SERVER_HOST`, `COMMIT_MSG` and `SKIP_CI`). Customers with source control are expected to use GitSync, and
  the customer who is the reason extract stays has no source control, so uses `NO_GIT`. That makes git mode the part
  of extract GitSync replaced. But maintenance only isn't the same as deprecated, and some customers may rely on it.
- **`deploy templates` mode.** It uploads connector templates to Web Modeler and commits `config.*`. Nothing above
  covers it. Find out whether anyone uses it, and whether Camunda Hub in 8.10 handles templates its own way.
- **`OAUTH2_GRANT_TYPE=password`.** The password grant is being phased out in OAuth generally (OAuth 2.1 removes
  it). Low priority; we don't know whether any customer uses it.

### Not candidates

The `CI` entrypoint behaviour for GitLab, `NO_GIT` for extract (the customer without source control needs it),
`MODEL_PATH`, `EXCLUDE`, and the remaining `OAUTH2_*` settings.

### How to deprecate

- Python settings: `deprecated=True` on the option, as the old names and `OAUTH_PLATFORM` already use.
- Settings only the shell scripts read (deploy's git settings, extract's git mode): print a warning from the script.
- List each deprecation on the wiki, with its replacement and the release it will be removed in.

## Things we have verified

Tested on Zeebe 8.7.5 and Camunda 8.10.7 in November 2026 (see `CLAUDE.md` for the full list):

- Zeebe's duplicate detection covers the whole deployment: one changed resource gives every resource in that
  deployment a new version.
- The comparison is on raw bytes and resource name. A whitespace-only change or a file rename creates a new version.
- A rejected deployment deploys nothing and lists the errors for every invalid file.
- On 8.10, a resource using `bindingType="deployment"` is rejected unless the resource it links to is in the same
  deployment, even if that resource already exists on the cluster. 8.7 doesn't check this.

## Open questions

- **Camunda's c8ctl CLI.** *Added 7 November 2026.* Camunda now has an official CLI,
  [c8ctl](https://github.com/camunda/c8ctl) (TypeScript, MIT licence, started January 2026, actively maintained;
  its docs are synced into the Camunda docs). Its `deploy` command covers much of what WMED deploy does:
  - deploys single files, lists of files or whole directories
  - recognises Camunda projects (folders with a `camunda.json`)
  - shows the resulting versions
  - has a watch mode
  - supports profiles per cluster, with a `--yes` flag for CI
  - can deploy the newer resource types the server accepts (`.md`, `.rpa`, `.json` and others), which is relevant
    to WMED issue #51

  The deploy docs we read don't mention a changed-only mode. c8ctl also supports plugins, and Camunda publishes
  several. So we need to decide whether WMED deploy competes with c8ctl, builds on it (for example, changed-only
  deploy as a c8ctl plugin, or WMED's image calling c8ctl), or concentrates on what c8ctl doesn't do. Worth
  answering before investing further in WMED's own deploy code or the move to REST.

  *Update, 14 November 2026:* not putting c8ctl in the WMED image yet. In the longer term we would probably
  consider using it inside the image for some operations, but that isn't a priority. For now, learn about it by
  running some integration test scenarios with c8ctl alongside WMED and comparing the results: resulting versions,
  behaviour when files are unchanged, all-or-nothing behaviour, error reporting and exit codes, project handling.
  Practical points:
  - c8ctl needs Node.js 22.18+ (`npm install @camunda8/cli`). Run it on the test host or in its own container,
    not in the WMED image.
  - It is built on Camunda's Orchestration Cluster REST API client, so it most likely needs an 8.8+ cluster. The
    test stack is pinned to 8.7.5, so these comparisons need a newer stack (which #100 suggests anyway).
  - The comparisons are for learning, so they shouldn't fail the build on a difference; record the differences
    here instead. They also depend on #99, so that a broken comparison is noticed.

- **Linked resources in changed-only mode.** If a changed file uses `bindingType="deployment"` for a call activity,
  business rule task or linked form, its target has to be in the same deployment on 8.10+, even when the target is
  unchanged. Changed-only mode must pull those targets in, which also gives them new versions. Should it follow
  links transitively?
- **Version support.** The REST deploy and resource-content endpoints need 8.8 or later. Do we still need to
  support 8.7 or earlier clusters, and if so, do they keep the gRPC path or get Web Modeler compatible mode only?
  *Review comment on #103:* everything new from Camunda targets 8.8+, so lean towards 8.8+ only; customers on 8.7
  and earlier keep using the current WMED release.
- **Deployment unit.** In Web Modeler compatible mode, is the unit the whole `MODEL_PATH`, or each directory
  (matching a Web Modeler project), as raised in issue #52? *Update, 12 November 2026:* Camunda now defines this.
  A Camunda project (called a process application before 8.10, when Web Modeler became part of Camunda Hub) is
  "the unit you build, test, and deploy together". Locally, a project is a folder with a `camunda.json` file in its
  root; the older `.process-application` marker is still recognised, and `camunda.json` wins if both are present.
  - **The file:** an empty `{}` is valid, and the only field so far is `hub.projectId`, which links the folder to a
    Camunda Hub project. Projects don't nest; a repo with several projects uses sibling folders.
  - **How tools deploy it:** Desktop Modeler and c8ctl always deploy the whole project as one deployment (c8ctl does
    this even when given a folder inside the project). Camunda Hub deploys either the whole project, all or
    nothing, or individual files.
  - **Proposed answer:** treat each folder with a `camunda.json` or `.process-application` as one deployment unit,
    which matches Desktop Modeler, c8ctl and Hub, and is also the natural boundary for changed-only mode. Folders
    with no marker fall back to the whole `MODEL_PATH`, as today.
  - **The catch:** Camunda Hub doesn't need the file, and GitSync doesn't appear to write it. Camunda's docs tell
    users who start in Hub to create it by hand after cloning. So many GitSync repos won't have one, and the
    fallback will often apply.
  - **Extract:** WMED records the Web Modeler project id in its own `config.yml`. Writing `camunda.json` with
    `hub.projectId` instead (or as well) would make extracted folders recognisable to Desktop Modeler and c8ctl. A
    small change, but extract is maintenance-only, so it's a judgement call.
  - Sources: Camunda docs "Projects" (`components/concepts/projects`) and c8ctl's `camunda.json` reference.
- **Tenants.** Each tenant is deployed separately, so one can succeed while another fails. Is that acceptable, and
  does changed-only mode compare per tenant?
- **Cost of downloading.** Changed-only mode downloads the latest version of every resource on each run. Is that
  acceptable for large projects? *Update, 7 November 2026:* Joe asked Camunda informally for an API that returns a
  resource's hash, and they didn't seem interested, so downloading is the approach to plan around. Ways to reduce
  the cost:
  - only download ids that exist locally
  - download in parallel
  - cache hashes by definition key, which is safe because a deployed version's content never changes, though the
    cache would have to survive between CI runs
- **Export noise.** Changes that don't affect meaning (attribute order, version stamps written by Web Modeler or
  GitSync) still count as changes. Do we accept that, or normalise before comparing?
