{{/*
Expand the name of the chart.
*/}}
{{- define "tekton-ci.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "tekton-ci.fullname" -}}
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
{{- define "tekton-ci.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "tekton-ci.labels" -}}
helm.sh/chart: {{ include "tekton-ci.chart" . }}
{{ include "tekton-ci.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "tekton-ci.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tekton-ci.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Generate docker config json for NCR
*/}}
{{- define "tekton-ci.dockerconfigjson" -}}
{{- $registry := .Values.docker.registry }}
{{- $username := .Values.ncr.credentials.username }}
{{- $password := .Values.ncr.credentials.password }}
{{- $email := .Values.ncr.credentials.email }}
{{- $auth := printf "%s:%s" $username $password | b64enc }}
{{- $config := dict "auths" (dict $registry (dict "username" $username "password" $password "email" $email "auth" $auth)) }}
{{- $config | toJson | b64enc }}
{{- end }}
