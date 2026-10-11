## ADDED Requirements

### Requirement: Optional main-container argv

The chart SHALL render per-component `command` and `args` as string lists on that component's main container without shell wrapping or template evaluation. Each list SHALL work independently. Absent, null or empty lists SHALL emit no corresponding key.

#### Scenario: Worker argv retains its values

- **WHEN** an enabled worker supplies command and args containing spaces, quotes, backslashes or shell-like text
- **THEN** its main container contains the exact string lists and other component and init commands are unchanged

#### Scenario: Existing image entrypoint remains in use

- **WHEN** command or args is absent, null or empty
- **THEN** the corresponding main-container field is absent

### Requirement: Component-local volume configuration

The chart SHALL render optional per-component volumes on its pod and volumeMounts on its main container, preserving supplied Kubernetes fields. Absent, null or empty lists SHALL omit the corresponding key. The chart MUST NOT copy these mounts into init containers or other components.

#### Scenario: API staging is bounded separately from worker storage

- **WHEN** the runtime fixture supplies an API disk-backed emptyDir with sizeLimit `256Mi` and a separate worker emptyDir with sizeLimit `64Mi`
- **THEN** each deployment contains its own volume and matching main-container mount, the frontend contains neither, and migration init containers acquire no new mounts

### Requirement: Resource maps retain their existing fallback

The chart SHALL support `ephemeral-storage` alongside existing resource quantities. A nonempty component resource map SHALL replace defaults exactly as before; otherwise default resources SHALL render. New resource defaults MUST NOT alter current consumers.

#### Scenario: API disk and worker memory limits remain independent

- **WHEN** the runtime fixture sets the API ephemeral-storage limit to `384Mi` and worker memory limit to `768Mi`
- **THEN** each value appears only on its intended main container and the frontend retains its original resources

#### Scenario: Default resources include caller-supplied ephemeral storage

- **WHEN** a component has no resource override and defaults include an ephemeral-storage request and limit
- **THEN** the main container receives the complete default resource map

### Requirement: Worker uses existing health and ingress settings

An enabled worker SHALL use the existing Service and named HTTP port from its explicit `service.targetPort`. Existing HTTP probe merge behavior SHALL remain unchanged. `ingress.enabled: false` MUST emit no Ingress for that worker.

#### Scenario: Internal worker has health checks without an ingress

- **WHEN** the worker fixture sets targetPort `3001`, enables HTTP probes and disables ingress
- **THEN** its Deployment and Service expose the configured port, probes use the named `http` port and configured path, and no worker Ingress is rendered

### Requirement: New values are validated without breaking old values

A values schema SHALL validate the new argv, volume, mount and resource shapes while accepting existing values, null resource maps, and omitted/empty optional fields. Unrelated existing chart and component fields SHALL remain usable.

#### Scenario: Invalid runtime shapes fail clearly

- **WHEN** lint/template receives a scalar command, a non-string argument, a mount missing its name or absolute path, an invalid emptyDir shape or a malformed resource map
- **THEN** schema validation fails with a nonzero result

#### Scenario: Existing defaults and consumer values stay valid

- **WHEN** defaults, current LyroChat-style values or valid runtime values are linted and rendered
- **THEN** schema validation succeeds

### Requirement: Existing deployment behavior is preserved

For values without the new fields, rendered resources SHALL remain identical except expected chart version metadata. Secret requirements, environment values, resource fallback, selectors and HTTP probe behavior MUST remain unchanged. Init commands SHALL still render as `["sh", "-c", command]` with the command string intact.

#### Scenario: Backend and frontend upgrade without render drift

- **WHEN** the same legacy fixture is rendered before and after this change
- **THEN** outputs match after normalizing only chart version labels, and omitted runtime keys remain absent

#### Scenario: Migration shell strings remain intact

- **WHEN** existing init-command fixtures contain quotes and backslashes
- **THEN** all existing deployment tests still pass with the exact shell argv

### Requirement: Version contract is reviewable before operational release

The change SHALL select an unreserved publishable chart version, document the new values and fixtures, and communicate the final version to T10. The proposed version is `0.7.0`; availability SHALL be rechecked before implementation. T09 MUST NOT package, publish or apply the chart.

#### Scenario: Platform receives an exact chart contract

- **WHEN** implementation finishes
- **THEN** T10 receives the selected version and fixture/value references, with publication explicitly recorded as a separate pending operational action

### Requirement: Publication requires explicit dispatch from main

The publication workflow SHALL use `workflow_dispatch` as its only event and SHALL guard the entire publish job with `github.ref == 'refs/heads/main'`. Existing release steps, token wiring, version guard and retention of earlier packages SHALL remain unchanged. Operators MUST complete the separately approved operational checklist before dispatch; version selection and repository merge MUST NOT authorize dispatch.

#### Scenario: Repository merge does not publish

- **WHEN** a commit is pushed or merged into main
- **THEN** the publication workflow is not triggered

#### Scenario: Dispatch selects another ref

- **WHEN** a manual dispatch selects a branch or tag other than `refs/heads/main`
- **THEN** the entire publish job is skipped before token creation, packaging or publication

#### Scenario: Approved operator release

- **WHEN** the separately approved operational checklist is complete and an operator explicitly dispatches from main
- **THEN** the existing release steps remain eligible to run with the unchanged version guard and package retention
