## Why

The attachment API needs bounded temporary disk, and its decoder needs a separate worker with its own resource limits. `app-chart` can already deploy arbitrary components, but it cannot override their main command or mount component-specific volumes.

## What Changes

- Add optional `components.<name>.command`, `args`, `volumes`, and `volumeMounts`, using Kubernetes field shapes. Omitted or empty lists emit no new fields.
- Document and validate `ephemeral-storage` within existing component/default resource maps. Keep the current whole-block resource fallback.
- Add a values schema, documentation, and render coverage for API upload staging and a worker with an explicit HTTP health port and disabled ingress.
- Preserve existing backend/frontend renders apart from chart version labels, HTTP probes, secret references, and init-container `sh -c` commands.
- Select chart version `0.7.0`, recheck availability at implementation time, and communicate the final version and fixture contract to T10.

## Capabilities

### New Capabilities

- `component-runtime`: Optional main-container entrypoints and volume mounts, bounded temporary-volume fixtures, schema validation, and backward-compatible rendering.

### Modified Capabilities

None. This repository has no existing OpenSpec capabilities.

## Impact

Work sites: `helm/app-chart/templates/deployment.yaml`, `values.yaml`, `Chart.yaml`, `README.md`, and the existing deployment/ingress tests. Add `helm/app-chart/values.schema.json` and reusable YAML test fixtures. Extend the existing CI workflow only where needed to run fixture/schema checks. No new chart dependency or application API change.

T09 belongs to E04, traces to P05/P06/D01/D06, has no ticket dependencies, and remains size S with high confidence. Its canonical scope and acceptance criteria are in [T09 at the approved source snapshot](https://github.com/lyrolab/lyrochat/blob/5bfe90748731588719615a45a68e75ac5908ab67/docs/projects/attachments/epics/E04-recovery-and-readiness/T09-bounded-runtime-chart.md).

Sensitive surfaces: preserve auth-related secret references and HTTP probe boundaries; preserve database migration init commands. Separate worker resources support bounded LLM input processing; prompt assembly and token budgeting do not change here.

Out of scope: worker application code and its production entrypoint, upload admission/cleanup, Terraform, Spaces credentials, frontend changes, chart packaging/publication, cluster apply, and feature exposure. T10 consumes this chart contract and T02 supplies the actual worker command.

Founding Engineer authorized a narrow publication-workflow repair on 2026-10-11 after Reviewer flagged automatic publication on merge. Replace the main-push trigger with `workflow_dispatch` only and guard the publish job with `github.ref == 'refs/heads/main'`. Preserve all release steps, token wiring, version checks and earlier packages. Document the separate operational approval required before dispatch; this repair does not authorize packaging or publication.
