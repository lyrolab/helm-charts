# Implementation verification

Chart `0.7.0` renders bounded API staging and a separate worker while preserving existing consumers. These are local render and validation results; no chart package, publication or cluster apply ran.

Tested implementation: `20b365b` on the issue branch. Final follow-up edits change only this record and task completion marks. Helm `v3.19.0`, chart-testing `v3.14.0`, yamllint `1.33.0`, yamale `6.0.0` and helm-unittest `v1.1.2` match the current CI workflow/action defaults. Tools were installed in run scratch storage; the host Python environment was unchanged.

## Results

- `helm lint --strict helm/app-chart`: passed.
- `ct lint --config ct.yaml --check-version-increment`: passed; Chart.yaml schema and values lint passed, and version increased from `0.6.0` to `0.7.0`.
- `helm unittest helm/app-chart`: passed, 10 suites / 59 tests.
- `helm unittest -f tests/deployment_test.yaml -f tests/ingress_test.yaml helm/app-chart`: passed, 2 suites / 21 tests.
- `helm lint --strict helm/app-chart -f <fixture>` and `helm template demo helm/app-chart -f <fixture>`: passed for `tests/fixtures/defaults.yaml`, `legacy.yaml` and `bounded-runtime.yaml`.
- Both lint and template rejected all 17 files in `tests/fixtures/invalid/`. Template failures explicitly reported values schema errors. CI runs the same fixture loop and requires schema failure, so an unrelated render error cannot count as a successful negative case.
- Defaults and legacy renders at baseline `976eba7` match the implementation byte-for-byte after replacing only the `helm.sh/chart` label value `app-chart-0.7.0` with `app-chart-0.6.0`. Baselines were captured before template/schema/version edits in disposable run scratch files.
- The README bounded-runtime YAML equals the checked-in fixture; strict lint and template of the extracted example passed. Full runtime render contains only backend/frontend Ingresses, plus the worker Service and Deployment.
- `openspec validate support-bounded-upload-volumes-and-worker-commands --strict`: passed.

Deployment tests assert complete API/worker volumes, mounts and resources; independent argv and literal shell/template-like characters; omitted/null/empty fields; default resource fallback and component replacement; unchanged frontend resources and migration init commands; preserved Kubernetes secret-volume fields; worker port `3001`, HTTP health probes and internal Service. Existing auth/secret, environment, probes and migration tests remain green.

Evidence must be rerun if chart templates, schema, values, fixtures or related test inputs change. Documentation-only and task-status edits do not invalidate chart results. GitHub `lint-test` CI also passed on implementation commit `20b365b` ([run](https://github.com/lyrolab/helm-charts/actions/runs/38150749371)). The final evidence/task-only commit starts another CI run; downstream stages must check that final status.

## Release contract

On 2026-10-11, after fetching latest main, `origin/main` remained `976eba7`. `origin/gh-pages` at `e90e8c4` listed versions/packages `0.1.0` through `0.6.0`, no tags/releases existed, and PR #10 was the only open PR. `0.7.0` was unreserved. `appVersion` remains `1.0.0`.

T10 ([LYR-91](/LYR/issues/LYR-91)) was notified of version `0.7.0`, `components.<name>.command`, `args`, `volumes`, `volumeMounts`, whole-block resource fallback/replacement and the fixture path. API disk is `256Mi` with ephemeral-storage limit `384Mi`; worker disk is `64Mi` with memory ceiling `768Mi`. Worker entrypoint, paths and health port are illustrative; T02/T10 own production settings.

The existing main-push publish workflow would publish automatically. Founding Engineer owns resolving that conflict before Reviewer merges. Version selection is not proof of package availability. Publication, deployment and exposure remain separate operational steps.
