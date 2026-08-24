# app-chart Helm Chart

A convention-driven, multi-component Helm chart for deploying applications with minimal configuration. This chart is designed to help you quickly deploy typical web applications (e.g., backend, frontend) using sensible defaults and conventions.

## Features & Philosophy

- **Convention over configuration**: Most settings are auto-detected or have smart defaults.
- **Component-based**: Define multiple components (e.g., backend, frontend) in your `values.yaml`.
- **Automatic secrets and image pull secrets handling**
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

### 3. Images & Pull Secrets
- Each component defines its own image repo/tag.
- Any secret in the namespace ending with `-registry` is added to `imagePullSecrets` automatically.

### 4. Secrets
- If `defaults.autoDetectSecrets: true`, the chart looks for a secret named `<release>-<component>-secrets` and mounts it as `envFrom`.
- You can override the secret name per component with `secretName`.

### 5. Environment Variables
- Define `env` as a map per component.
- For backend/frontend, URLs are set automatically for inter-component communication:
  - backend: `SERVER_URL`, `FRONTEND_URL` (if frontend enabled)
  - frontend: `NEXT_PUBLIC_BACKEND_URL` (if backend enabled)

### 6. Resources
- Set per component, or use global defaults via `defaults.resources`.
- A component's `resources` block replaces the default block outright — it is not merged — so set both `limits` and `requests` when you override.
- Defaults deliberately keep `requests` low and `limits` wide. Requests are what the scheduler reserves, and therefore what drives node-pool cost; limits only cap burst. A container that does real work at startup (framework bootstrap, migrations, telemetry SDK init) needs far more CPU for its first minute than it will ever use again, and a `requests == limits` budget denies it that burst.

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

### 9. Autoscaling
- If `autoscaling.enabled` is true, an HPA is created for the component.
- Configure min/max replicas and CPU utilization threshold.

### 10. Services
- Each component gets a Service named `<release>-<component>`.
- Service type/port can be set per component or via `defaults.service`.

### 11. Ingress
- Ingress is enabled by default (`defaults.ingress.enabled: true`).
- Each component can override ingress settings.
- For `backend`, path is `/api(/|$)(.*)` with rewrite; for others, `/`.
- Ingress class, annotations, and hosts are configurable.

---

## Example: Minimal `values.yaml`

```yaml
defaults:
  autoDetectSecrets: true
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
- `_helpers.tpl`: Contains naming, label, and resource helpers.
