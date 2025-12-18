{{/*
Expand the name of the chart.
*/}}
{{- define "app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "app.labels" -}}
helm.sh/chart: {{ include "app.chart" . }}
{{ include "app.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.defaults.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Get component image tag with defaults
*/}}
{{- define "app.getImageTag" -}}
{{- $component := . -}}
{{- $tag := $component.image.tag | default $.Values.defaults.image.tag -}}
{{- $tag -}}
{{- end -}}

{{/*
Get component resources with defaults
*/}}
{{- define "app.getResources" -}}
{{- $component := . -}}
{{- if $component.resources -}}
{{- toYaml $component.resources -}}
{{- else -}}
{{- toYaml $.Values.defaults.resources -}}
{{- end -}}
{{- end -}}

{{/*
Get service settings with defaults
*/}}
{{- define "app.getService" -}}
{{- $component := .component -}}
{{- $root := .root -}}
type: {{ $component.service.type | default $root.Values.defaults.service.type }}
port: {{ $component.service.port | default $root.Values.defaults.service.port }}
targetPort: {{ $component.service.targetPort }}
{{- end -}}

{{/*
Backend environment variables
*/}}
{{- define "app.backendEnvVars" -}}
{{- $component := .component -}}
{{- $root := .root -}}
{{- if eq $component.name "backend" }}
- name: SERVER_URL
  value: "https://{{ $component.host }}/api"
{{- end}}
{{- if and (eq $component.name "backend") ($root.Values.components.frontend.enabled) }}
- name: FRONTEND_URL
  value: "https://{{ $root.Values.components.frontend.host }}"
{{- end }}
{{- if and (eq $component.name "backend") ($root.Values.keycloak.realm) }}
- name: KEYCLOAK_REALM
  value: {{ $root.Values.keycloak.realm | quote }}
- name: KEYCLOAK_CLIENT_ID
  value: "app"
- name: KEYCLOAK_URL
  value: "https://sso.lyrolab.fr"
{{- end }}
{{- $otelEnabled := $root.Values.defaults.otel.enabled }}
{{- if $component.otel }}
  {{- $otelEnabled = $component.otel.enabled | default $root.Values.defaults.otel.enabled }}
{{- end }}
{{- if $otelEnabled }}
- name: OTEL_EXPORTER_URL
  value: "http://otelcol-dev-collector.lyro-opentelemetry.svc.cluster.local:4317"
{{- end }}
{{- end -}}

{{/*
PostHog domain (EU region)
*/}}
{{- define "app.posthogDomain" -}}
eu.i.posthog.com
{{- end -}}

{{/*
PostHog assets domain (EU region)
*/}}
{{- define "app.posthogAssetsDomain" -}}
eu-assets.i.posthog.com
{{- end -}} 
