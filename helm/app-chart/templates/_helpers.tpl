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