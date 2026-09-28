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
Labels for a component's resources; the version is the tag the component runs
*/}}
{{- define "app.componentLabels" -}}
{{- $root := .root -}}
helm.sh/chart: {{ include "app.chart" $root }}
{{ include "app.selectorLabels" $root }}
app.kubernetes.io/version: {{ .component.image.tag | default $root.Values.defaults.image.tag | quote }}
app.kubernetes.io/managed-by: {{ $root.Release.Service }}
app.kubernetes.io/component: {{ .name }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

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
  value: {{ $root.Values.keycloak.clientId | quote }}
- name: KEYCLOAK_URL
  value: {{ $root.Values.keycloak.url | quote }}
{{- end }}
{{- if and (eq $component.name "backend") ($root.Values.posthog.enabled) }}
- name: POSTHOG_HOST
  value: "https://{{ $root.Values.posthog.host }}"
{{- end }}
{{- $otel := mergeOverwrite (deepCopy $root.Values.defaults.otel) ($component.otel | default dict) }}
{{- if $otel.enabled }}
- name: OTEL_EXPORTER_URL
  value: {{ $otel.exporterUrl | default $root.Values.defaults.otel.exporterUrl | quote }}
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

{{/*
ServiceAccount used by every component
*/}}
{{- define "app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "app.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}
