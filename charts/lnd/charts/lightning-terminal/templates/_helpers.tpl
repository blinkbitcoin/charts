{{/*
Expand the name of the chart.
*/}}
{{- define "lightning-terminal.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "lightning-terminal.fullname" -}}
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
{{- define "lightning-terminal.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "lightning-terminal.labels" -}}
helm.sh/chart: {{ include "lightning-terminal.chart" . }}
{{ include "lightning-terminal.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "lightning-terminal.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lightning-terminal.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "lightning-terminal.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "lightning-terminal.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the role to use
*/}}
{{- define "lightning-terminal.roleName" -}}
{{- include "lightning-terminal.fullname" . }}-role
{{- end }}

{{/*
Create the name of the role binding to use
*/}}
{{- define "lightning-terminal.roleBindingName" -}}
{{- include "lightning-terminal.fullname" . }}-rolebinding
{{- end }}

