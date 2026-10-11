# app-chart Helm Chart

A convention-driven, multi-component Helm chart for deploying applications with minimal configuration. This chart is designed to help you quickly deploy typical web applications (e.g., backend, frontend) using sensible defaults and conventions.

## Features & Philosophy

- **Convention over configuration**: Most settings are auto-detected or have smart defaults.
- **Component-based**: Define multiple components (e.g., backend, frontend) in your `values.yaml`.
- **Convention-based secrets and a templated ServiceAccount for image pull secrets, with no Helm `lookup`** (renders the same under ArgoCD as under `helm install`)
- **Standardized labels, selectors, and resource management**
- **Ingress, Service, Deployment, and Autoscaling support**

---

## Quick Start

1. **Copy this chart** into your Helm charts repo or reference it as a dependency.
2. **Define your components** in `values.yaml`:

```yaml
components:
  backend:
    enabled: true
    name: backend
    image:
      repository: myrepo/backend
      tag: latest
  frontend:
    enabled: true
    name: frontend
    image:
      repository: myrepo/frontend
      tag: latest
```

3. **Install the chart**:

```sh
helm install my-app ./app-chart -f values.yaml
```

---

## Conventions & Defaults

### 1. Components
- Define each app part (backend, frontend, etc.) under `components`.
- Enable with `enabled: true`.
- Each component can have its own image, env, resources, etc.

### 2. Naming & Labels
- Resources are named `<release>-<component>` by default.
- Standard Kubernetes labels and selectors are used for all resources.
- `app.kubernetes.io/version` on a component's resources is the image tag that component runs (`image.tag`, falling back to `defaults.image.tag`).

### 3. Images & Pull Secrets
- Each component defines its own image repo/tag.
- Pull secrets are declared on a ServiceAccount the chart creates and every component runs as:

```yaml
serviceAccount:
  create: true
  imagePullSecrets:
    - github-registry
```

- The ServiceAccount is named after the release unless `serviceAccount.name` is set. With `create: false`, a non-empty `serviceAccount.name` points pods at an existing ServiceAccount; otherwise pods run as the namespace `default` ServiceAccount.

### 4. Secrets
- Every component mounts `<release>-<component>-secrets` as `envFrom` with `optional: true`, so the pod starts whether or not that secret exists.
- `secretName` per component overrides the name; an explicit `secretName` is mounted without `optional`, so a missing secret blocks the pod instead of starting it without its configuration.

### New in 0.7.0
- Optional per-component `command`, `args`, `volumes` and `volumeMounts` (see Component runtime).
- Values schema checks runtime field shapes and resource quantities, including `ephemeral-storage`.

### New in 0.6.0
- `featureFlags` block: `FLIPT_URL` and `FLIPT_ENVIRONMENT` on the backend (see Environment Variables).

### Breaking changes in 0.5.0
- Every component ingress sends security headers through a `configuration-snippet` (see Ingress). `X-Frame-Options: SAMEORIGIN` blocks cross-origin framing. Set `defaults.ingress.securityHeaders.enabled: false` to keep 0.4.0 behaviour.
- `otel.enabled: false` is honoured, so `frontend` (off in the chart values) no longer receives `OTEL_EXPORTER_URL`. Set `components.frontend.otel.enabled: true` if it exports telemetry.
- A component with ingress annotations but no `path` is served at `/` with `Prefix`, instead of being rewritten to `/$2`.
- A component's `autoscaling` block is merged over `defaults.autoscaling` instead of replacing it.
- `app.kubernetes.io/version` on component resources is the component's image tag, not `defaults.image.tag`. Selectors are unchanged.
- Keycloak env values are unchanged by default; they now come from `keycloak.url`, `keycloak.clientId` and `keycloak.frontendClientId`.

### Breaking changes in 0.4.0
- Pull secrets are no longer discovered from secrets ending in `-registry`. Declare them under `serviceAccount.imagePullSecrets` with `serviceAccount.create: true`.
- `defaults.autoDetectSecrets` and `defaults.secretName` are removed. The convention secret is always referenced (optionally), and `components.<name>.secretName` remains the override.

### 5. Environment Variables
- Define `env` as a map per component.
- For backend/frontend, URLs are set automatically for inter-component communication:
  - backend: `SERVER_URL`, `FRONTEND_URL` (if frontend enabled)
  - frontend: `NEXT_PUBLIC_BACKEND_URL` (if backend enabled)
- With `keycloak.realm` set, the backend receives `KEYCLOAK_REALM`, `KEYCLOAK_URL` and `KEYCLOAK_CLIENT_ID`, and the frontend the `NEXT_PUBLIC_`/`VITE_` equivalents. `keycloak.url` (default `https://sso.lyrolab.fr`), `keycloak.clientId` (backend, default `app`) and `keycloak.frontendClientId` (frontend, default `app`) set the values.
- With `featureFlags.enabled: true`, the backend receives `FLIPT_URL` (default `http://flipt.lyrolab-flipt.svc.cluster.local:8080`, the company Flipt) and `FLIPT_ENVIRONMENT` (default `<fullname>-<stage>`, e.g. `lyrochat-production`, overridable with `featureFlags.environment`). The API token is not a value: put `FLIPT_TOKEN` in the backend secret.
- `OTEL_EXPORTER_URL` is set when OpenTelemetry is enabled for the component. `components.<name>.otel` is merged over `defaults.otel`, so `otel.enabled: false` on a component turns it off; the chart ships it on for `backend` and off for `frontend`.

### 6. Resources
- Set per component, or use global defaults via `defaults.resources`.
- A component's `resources` block replaces the default block outright — it is not merged — so set both `limits` and `requests` when you override.
- Defaults deliberately keep `requests` low and `limits` wide. Requests are what the scheduler reserves, and therefore what drives node-pool cost; limits only cap burst. A container that does real work at startup (framework bootstrap, migrations, telemetry SDK init) needs far more CPU for its first minute than it will ever use again, and a `requests == limits` budget denies it that burst.

- Requests and limits accept `ephemeral-storage` alongside CPU and memory. No new storage default is set. Missing, null or empty component resources use the complete default resource block.

### Component runtime

| Component value | Kubernetes field | Shape |
| --- | --- | --- |
| `command` | Main container `command` | String list |
| `args` | Main container `args` | String list |
| `volumes` | Pod `volumes` | Kubernetes Volume list |
| `volumeMounts` | Main container `volumeMounts` | Kubernetes VolumeMount list |

`command` and `args` work independently and pass argv unchanged. The chart adds no shell wrapper and does not evaluate templates or shell expressions. Use an explicit shell command if you need one. Missing, null or empty lists emit no keys, keeping image entrypoint defaults. Volumes and mounts belong only to their component; migration init containers receive no new mounts or resource limits.

The schema validates list types, string argv, volume names, absolute mount paths, `emptyDir` shape and resource maps. Other Kubernetes volume sources and mount fields remain usable. Kubernetes validates quantity semantics, duplicate names and volume references.

### 7. Probes
- Enable per component with `probes.enabled: true` (on by default for `backend`).
- Three probes are emitted against `probes.path` (default `/health`) on the component's HTTP port: `startupProbe`, `livenessProbe`, `readinessProbe`.
- The startup probe owns boot. Kubernetes runs neither liveness nor readiness until it succeeds, so boot duration and hang detection are independent knobs. The default budget is `periodSeconds: 5 × failureThreshold: 60` = 5 minutes.
- Timings are configurable at `defaults.probes` and per component; a component's block is deep-merged over the defaults, so `probes: { startup: { failureThreshold: 120 } }` keeps every other setting.

```yaml
components:
  worker:
    probes:
      enabled: true
      path: /healthz
      startup:
        failureThreshold: 120
```

**Diagnosing a boot that gets killed.** A container SIGKILLed by a failing liveness probe reports `exitCode: 137` with `reason: Error`. That is not `reason: OOMKilled` — 137 alone does not mean the container ran out of memory. If the events show `Liveness probe failed: connection refused` and `kubectl top` shows CPU pinned at the limit, the container is being CPU-throttled through its probe window: widen `limits.cpu` and/or `probes.startup.failureThreshold`.

### 8. Init Containers
- Define `initContainers` as a list per component, each with `name` and `command`.
- `command` runs as a single `sh -c` argument, so quotes and backslashes inside it reach the shell unchanged.

### 9. Autoscaling
- If `autoscaling.enabled` is true, an HPA is created for the component.
- Configure min/max replicas and CPU utilization threshold.
- A component's `autoscaling` block is merged over `defaults.autoscaling`, so it only needs the keys it changes.

### 10. Pod Disruption Budgets
- Opt in with `podDisruptionBudget.enabled: true` in `defaults` or per component (merged over the defaults).
- The budget allows `maxUnavailable` (default `1`) pods down at a time and is only rendered for components running more than one replica (`replicaCount`, or `autoscaling.minReplicas` when autoscaling). A budget on a single replica could only block node drains.

### 11. Services
- Each component gets a Service named `<release>-<component>`.
- Service type/port can be set per component or via `defaults.service`.

### 12. Ingress
- Ingress is enabled by default (`defaults.ingress.enabled: true`).
- Each component can override ingress settings.
- For `backend`, path is `/api(/|$)(.*)` with rewrite; for others, `/`. The `/$2` rewrite and `ImplementationSpecific` path type apply only when the resolved path is not `/`.
- Ingress class, annotations, and hosts are configurable.
- `securityHeaders`, `rateLimit` and `tls` live under `defaults.ingress` and can be overridden per component under `components.<name>.ingress`; a component's block is merged over the defaults.

**Security headers.** On by default. Each ingress gets a `configuration-snippet` of `more_set_headers` for `Strict-Transport-Security`, `X-Content-Type-Options`, `Referrer-Policy`, `X-Frame-Options` and `Permissions-Policy`. Set a header's value to `""` to drop it, or `securityHeaders.enabled: false` to send none. The controller must allow snippet annotations (`allow-snippet-annotations: true`, and `annotations-risk-level: Critical` on ingress-nginx 1.12+). A component's own `nginx.ingress.kubernetes.io/configuration-snippet` annotation is appended after the headers. Content-Security-Policy is left to each app.

```yaml
components:
  frontend:
    ingress:
      securityHeaders:
        frameOptions: DENY
        hsts: ""
```

**Rate limiting.** `rateLimit.rps` sets `nginx.ingress.kubernetes.io/limit-rps` per client IP, with `limit-burst-multiplier` from `rateLimit.burstMultiplier` (default `5`). Unset means unlimited.

**TLS.** `tls.enabled: true` declares TLS for the component host with `tls.secretName` (default `lyrolab-fr-tls`), which must exist in the release namespace. Declaring TLS makes ingress-nginx redirect HTTP to HTTPS, so the upstream proxy must reach the origin over HTTPS.

---

## Example: Minimal `values.yaml`

```yaml
defaults:
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
  service:
    type: ClusterIP
    port: 80
  ingress:
    enabled: true
    className: "nginx"
    hosts: []
  image:
    pullPolicy: IfNotPresent
    tag: latest

components:
  backend:
    enabled: true
    name: backend
    image:
      repository: myrepo/backend
      tag: latest
    service:
      targetPort: 8080
    env:
      NODE_ENV: production
  frontend:
    enabled: true
    name: frontend
    image:
      repository: myrepo/frontend
      tag: latest
    service:
      targetPort: 3000
    env:
      NODE_ENV: production
```

---

## Advanced Usage

- **Override resource names**: Use `nameOverride` or `fullnameOverride`.
- **Custom secrets**: Set `secretName` per component.
- **Custom ingress/service**: Override per component or use global defaults.
- **Add more components**: Just add more entries under `components`.

---

## Template Reference

- `deployment.yaml`: Handles Deployments for each enabled component.
- `service.yaml`: Creates a Service for each enabled component.
- `ingress.yaml`: Creates Ingress for each enabled component (with smart path/host conventions).
- `autoscaling.yaml`: Creates HPA if enabled for a component.
- `pdb.yaml`: Creates a PodDisruptionBudget if enabled for a component running more than one replica.
- `_helpers.tpl`: Contains naming, label, and resource helpers.

## Example: Bounded upload staging and a separate worker

Chart `0.7.0` supports this contract. Version selection does not mean it has been published; publication and deployment follow the separate operational checklist.

This complete render fixture is also in `tests/fixtures/bounded-runtime.yaml`. Worker argv, paths and health port are illustrative; T02 supplies the production entrypoint and T10 configures it. The worker keeps an internal Service and HTTP probes while its ingress is disabled.

```yaml
stage: fixture
components:
  backend:
    enabled: true
    host: chat.example.invalid
    image:
      repository: example.invalid/backend
    volumes:
      - name: upload-tmp
        emptyDir:
          sizeLimit: 256Mi
    volumeMounts:
      - name: upload-tmp
        mountPath: /var/lib/lyrochat/uploads
        readOnly: false
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
        ephemeral-storage: 256Mi
      limits:
        cpu: 1000m
        memory: 512Mi
        ephemeral-storage: 384Mi
  worker:
    enabled: true
    image:
      repository: example.invalid/backend
    command: [node]
    args: [dist/fixture-worker.js, '--label=spaces "quotes" \\ $HOME $(echo fixture) {{ .Values.stage }}']
    service:
      targetPort: 3001
    ingress:
      enabled: false
    probes:
      enabled: true
      path: /healthz
    volumes:
      - name: decode-tmp
        emptyDir:
          sizeLimit: 64Mi
    volumeMounts:
      - name: decode-tmp
        mountPath: /var/lib/lyrochat/decode
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
        ephemeral-storage: 64Mi
      limits:
        cpu: 1000m
        memory: 768Mi
        ephemeral-storage: 128Mi
  frontend:
    enabled: true
    host: chat.example.invalid
    image:
      repository: example.invalid/frontend
```

The API uses a disk-backed `emptyDir` capped at `256Mi` and an ephemeral-storage limit of `384Mi`. The worker has its own `64Mi` temporary volume and `768Mi` memory ceiling. Omitting `medium` avoids tmpfs memory charges. These volumes are pod-local and are not shared between API and worker pods.

Application code owns private directories/files, upload admission, deadlines and cleanup. Kubernetes size limits alone do not prove privacy, secure erasure or an upload-time hard byte cap. Files disappear when the pod is removed; container restarts can leave files behind.

Render without publishing or applying:

```sh
helm lint --strict helm/app-chart -f helm/app-chart/tests/fixtures/bounded-runtime.yaml
helm template demo helm/app-chart -f helm/app-chart/tests/fixtures/bounded-runtime.yaml
```

## Publication

Complete the separately approved operational release checklist, then explicitly run **Publish Helm Chart** with `workflow_dispatch` from `main`. Other selected refs skip the publish job. Ordinary pushes and merges do not start publication. Selecting chart `0.7.0` or merging this PR does not authorize dispatch.
