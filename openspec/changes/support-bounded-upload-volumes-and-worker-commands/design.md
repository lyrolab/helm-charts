## Context

The execution branch matches `origin/main` at `976eba7` (2026-10-11). `app-chart` is `0.6.0`. There is no values schema or OpenSpec history in this repository; the existing YAML unittest suites define its render behavior.

`deployment.yaml` already iterates arbitrary enabled components. It emits one main container, a named `http` port from `service.targetPort`, optional HTTP probes, and resources from the component or `defaults.resources`. A component resource block replaces defaults; it is not merged. Init commands are strings passed intact as `["sh", "-c", command]`. `ingress.yaml` already honors `ingress.enabled: false`. Every enabled component gets a Service.

The approved [attachment design](https://github.com/lyrolab/lyrochat/blob/5bfe90748731588719615a45a68e75ac5908ab67/docs/projects/attachments/design.md) sets API temporary disk to 256 MiB, API ephemeral-storage limit to 384 MiB, worker temporary disk to 64 MiB, and worker memory ceiling to 768 MiB. Application code owns upload admission, private file creation, deadlines, decoding and cleanup. The chart makes these limits configurable; it does not enforce application admission.

## Goals / Non-Goals

Goals: support component-specific entrypoints and temporary mounts, validate new fields, retain existing renders, and give T10 an exact version and values contract. Keep T09 independent of application implementation.

Non-goals: new workload types, sidecars, service/probe redesign, global command/volume defaults, mount inheritance by init containers, production worker code, infrastructure provisioning, publishing or deployment.

## Decisions

### Use Kubernetes field names directly

| Value | Rendered location | Shape |
| --- | --- | --- |
| `components.<name>.command` | `spec.template.spec.containers[0].command` | List of strings |
| `components.<name>.args` | `spec.template.spec.containers[0].args` | List of strings |
| `components.<name>.volumeMounts` | `spec.template.spec.containers[0].volumeMounts` | Kubernetes VolumeMount list |
| `components.<name>.volumes` | `spec.template.spec.volumes` | Kubernetes Volume list |
| `components.<name>.resources` | `spec.template.spec.containers[0].resources` | Existing ResourceRequirements map |

Render nonempty lists through `toYaml` with the appropriate indentation, guarded by normal Helm `with` blocks. Absent, null or empty lists omit their YAML keys. Main commands are argv lists, with no automatic shell wrapper, interpolation or `tpl`. `command` and `args` can be configured independently. Leave init commands and their environments untouched.

A worker is an ordinary component with `enabled: true`, an image, explicit `service.targetPort`, `ingress.enabled: false` and HTTP probes. Its health endpoint can use `/health` or the existing per-component path override. It still gets the existing internal Service. A special worker mode or probe type adds no value to this ticket.

### Keep resource fallback intact

Existing `toYaml` already renders `ephemeral-storage`. Add documentation, schema coverage and assertions for that key without changing fallback semantics. A supplied component resource map must include the requests/limits its caller needs; the chart does not fill missing CPU or memory entries. Do not introduce ephemeral-storage defaults for current backend/frontend consumers.

Volumes belong to the selected pod; mounts and resources apply only to its main container. Do not copy them into migration init containers. The fixture must show that the API, worker and frontend remain independent.

### Add a small, compatible values schema

Create `helm/app-chart/values.schema.json` using Helm's supported JSON Schema format. Validate optional command/args lists of strings; volumes as object lists with a nonempty `name`; and mounts as object lists with a nonempty `name` and absolute `mountPath`. Validate the shapes of `emptyDir`, its optional `sizeLimit` quantity, and optional mount properties used by the fixture. Preserve Kubernetes volume source fields rather than limiting the chart to `emptyDir`.

Validate optional default/component `resources.requests` and `limits` maps, including string or numeric Kubernetes quantity values for `ephemeral-storage`. Accept existing null resource maps and optional/null/empty lists. Keep existing unrelated chart/component fields extensible; this is not a full schema retrofit. Do not add global required fields that reject current disabled components.

Helm lint/template must reject malformed list types, non-string argv entries, missing mount names/paths, invalid emptyDir shapes, and malformed resource maps. Kubernetes quantity semantics, duplicate names and mount/source cross-references remain Kubernetes validation concerns; do not build a custom validator here.

### Use reusable values fixtures

Add YAML data under `helm/app-chart/tests/fixtures/` and use the existing helm-unittest runner. Cover defaults, legacy backend/frontend values resembling active platform values, and API/worker runtime values. Keep disposable baseline render outputs in the run scratch directory.

The bounded-runtime fixture must include:

- Backend `upload-tmp` disk-backed `emptyDir: {sizeLimit: 256Mi}` mounted at an absolute private staging path such as `/var/lib/lyrochat/uploads`, with `resources.limits.ephemeral-storage: 384Mi`. Preserve CPU/memory resources when overriding the block.
- A separately named worker using a fixture argv command, `service.targetPort: 3001`, `probes.enabled: true`, disabled ingress, `emptyDir: {sizeLimit: 64Mi}`, and `resources.limits.memory: 768Mi`.
- A frontend without the new fields to prove mount/resource isolation.

The worker command/path and health port in this fixture are illustrative. T10 must use T02's actual application entrypoint and health contract; T09 does not depend on that code. Do not place a real application secret or file in fixtures. A pod-local emptyDir is not shared storage. Application code creates private directories/files and removes leftovers; Kubernetes size limits alone do not prove privacy, secure erasure, prompt isolation or an upload-time hard byte cap. Keep `medium` omitted for disk-backed staging rather than charging a tmpfs to memory.

### Select and communicate the release version

Use `0.7.0` and leave `appVersion` unchanged. On 2026-10-11, the remote `gh-pages` index at `e90e8c4` listed only `0.1.0`–`0.6.0`, no tags/releases reserved `0.7.0`, and no open PR existed. Recheck the index, packaged filenames, tags/releases and open PRs immediately before bumping the chart. If another change has taken it, select the next free version and update this proposal, README and T10 handoff together.

Notify T10 ([LYR-91](/LYR/issues/LYR-91)) of the exact selected version, four field names, resource fallback and fixture location. State that publication is pending the operational checklist; selection is not proof of availability from the chart repository.

## Risks / Trade-offs

- New schema rejects old values → run all existing suites and render current-style backend/frontend values; allow unrelated fields and existing nulls.
- YAML indentation or shared-loop leakage → assert complete argv/volume/mount/resource values by deployment name, plus absence on untouched components and init containers.
- Default render drift → compare pre/post renders of the same fixtures, normalizing only `helm.sh/chart` version labels. Names, selectors, environments, resources and probes must remain identical.
- EmptyDir capacity and worker ceilings are runtime behavior → retain the approved numeric caps, but report renders as local evidence. Live resource/decoding/cleanup gates belong to the broader project.
- Publication on merge → remove the automatic trigger under the scoped lead direction below. A manual dispatch remains a release act requiring separate operational approval. Do not run it during verification.

## Migration Plan

This is an additive chart upgrade. Existing values retain their behavior except the chart version label. No database migration or secret change is required. T10 adds worker/upload settings only after this contract is reviewed, and applies a version pin only after publication is separately completed. Reverting chart capability after platform starts using these fields would drop commands/mounts; coordinate any later rollback with T10.

## Verification and Current Evidence

On the unchanged chart at `976eba7`, `helm lint --strict helm/app-chart` passed and `helm template baseline helm/app-chart` passed with no enabled default components. Strict lint and template also passed with current platform production-style values (386 rendered lines); these are baseline chart checks, not new-feature verification. This host has Helm `v3.16.4`, while CI uses `v3.19.0`; `ct` and helm-unittest are not installed locally. No chart unittest, chart-testing or new-feature check is claimed to have run during proposal work.

Applier must run the canonical CI commands (`helm lint --strict helm/app-chart`, `ct lint --config ct.yaml --check-version-increment`, `helm unittest helm/app-chart`), focused deployment/ingress suites, and strict lint/template for legacy and bounded-runtime fixtures. Use CI's Helm/chart-testing tooling and helm-unittest `v1.1.2`; record any unavailable checks as unrun. Add schema-negative cases to the existing CI path with explicit expected failure, not a custom test framework. No credentials or cluster are required for T09.

## Open Questions

No product or chart design question blocks implementation. Reviewer must recheck the publication finding after the scoped repair and fresh CI. T02/T10 own production worker argv, runtime paths, secrets and health endpoint; those are outside this generic chart change.

## Scoped publication repair (2026-10-11)

Founding Engineer authorized this repair on the same issue, branch and PR after Reviewer's publication finding. The workflow SHALL expose only `workflow_dispatch`; ordinary main pushes, pull requests, tags, schedules and reusable-workflow calls cannot trigger it. The publish job SHALL require `github.ref == 'refs/heads/main'`, before any runner steps, so another selected ref skips token creation, packaging and publication.

Keep every release step unchanged, including the GitHub App token, version guard and retention of earlier packages. Add no credential, environment, chart-version or application change. Operators must complete the separately approved operational checklist before explicitly dispatching from main. Version selection and repository merge grant no dispatch approval.

Validate YAML and Actions syntax with available tools. Inspect the parsed event map and job condition, compare release steps to `6a79233`, and check main/non-main ref outcomes without executing the workflow. Obtain fresh lint-test CI on the repaired head. Chart evidence remains reusable while its exact template/schema/values/fixture/test inputs remain unchanged. Only Reviewer can clear the publication finding.
