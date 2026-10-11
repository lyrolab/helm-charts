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

At the original implementation/review head, the main-push publish workflow would publish automatically. The scoped repair below replaces that trigger; Reviewer must recheck the finding before merge. Version selection is not proof of package availability. Publication, deployment and exposure remain separate operational steps.

## Publication workflow rework (2026-10-11)

Founding Engineer authorized the narrow repair after Reviewer's HIGH publication finding. Latest fetched `origin/main` remains `976eba72f7f63e834bc87f04748e98159029622a`; branch preflight passed and the reviewed base is `6a7923327aa00f92e6401af72dc1d1b76a78fdbf`.

Static checks passed on the repaired workflow:

- Actionlint `1.7.12`: `actionlint -config-file <scratch>/actionlint.yaml -shellcheck='' .github/workflows/publish-helm-chart.yml`. The scratch config declares the existing `ubicloud-standard-2` label under `self-hosted-runner.labels`. The first run without this config reported only the unknown runner label; the configured run passed. Shellcheck integration was disabled; this is Actions syntax evidence, not a new shell analysis. All shell steps are unchanged.
- PyYAML `6.0.1` with `BaseLoader` parsed the workflow, preserving the `on` event key. Its only key is `workflow_dispatch`; there is no push, pull_request, tag, schedule or workflow_call event. The publish-job condition equals `github.ref == 'refs/heads/main'`. The unchanged steps and runner compare equal to the parsed workflow at `6a79233`.
- The exact equality condition admits `refs/heads/main` and rejects `refs/heads/rework` and `refs/tags/0.7.0`. GitHub evaluates the job condition before running its steps, so non-main dispatches cannot create the token, package or publish. This is static evidence; no dispatch was executed.
- `git diff 6a79233 -- helm/app-chart ':(exclude)helm/app-chart/README.md'` and `git diff 6a79233 -- .github/workflows/lint-test-helm-chart.yml` are empty. Chart template/schema/values/fixture/test inputs and lint-test workflow are unchanged, so earlier chart evidence remains valid. Only an operator note was appended to the chart README; its render example is unchanged.
- `openspec validate support-bounded-upload-volumes-and-worker-commands --strict` and `git diff --check`: passed.

Reproduce the parsed boundary/step checks without invoking any workflow:

```sh
python3 - <<'PY'
from pathlib import Path
import subprocess, yaml
p = '.github/workflows/publish-helm-chart.yml'
w = yaml.load(Path(p).read_text(), Loader=yaml.BaseLoader)
b = yaml.load(subprocess.check_output(['git', 'show', '6a79233:' + p], text=True), Loader=yaml.BaseLoader)
assert set(w['on']) == {'workflow_dispatch'}
assert w['jobs']['publish']['if'] == "github.ref == 'refs/heads/main'"
assert w['jobs']['publish']['steps'] == b['jobs']['publish']['steps']
assert w['jobs']['publish']['runs-on'] == b['jobs']['publish']['runs-on']
for ref in ['refs/heads/main', 'refs/heads/rework', 'refs/tags/0.7.0']:
    print(ref, ref == 'refs/heads/main')
PY
```

Fresh lint-test CI passed on repair commit `4eced30dff04c868228dc4264896084642b47a24` ([run](https://github.com/lyrolab/helm-charts/actions/runs/38151831163)): strict Helm lint, chart-testing/version increment, all 59 unit tests, valid-fixture renders and all schema-negative fixtures. PR #10 now describes the release boundary, with apply complete and simplify/review rework pending. All three rework tasks are complete. This follow-up changes only task/evidence records; the final head receives another CI run whose result must be checked before handoff and recorded in the issue. This workflow evidence must be rerun if its trigger, condition, runner or steps change. Chart-input changes invalidate the earlier chart results. No chart packaging, publication, cluster apply, live credentials or exposure ran. Operational checklist approval and explicit dispatch from main remain separate from version selection and repository merge. Only Reviewer can clear the publication finding.
