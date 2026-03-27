{{/*
Expand the name of the chart.
*/}}
{{- define "rhbk-datagrid.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "rhbk-datagrid.fullname" -}}
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

{{/* ---- Component full names ---- */}}

{{- define "rhbk-datagrid.rhbk" -}}
rhbk
{{- end }}

{{- define "rhbk-datagrid.datagrid" -}}
datagrid
{{- end }}

{{- define "rhbk-datagrid.datagridHeadless" -}}
datagrid-headless
{{- end }}

{{- define "rhbk-datagrid.postgresql" -}}
postgresql
{{- end }}

{{/* ---- Common labels ---- */}}

{{- define "rhbk-datagrid.labels" -}}
helm.sh/chart: {{ include "rhbk-datagrid.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Values.rhbk.image.tag | quote }}
{{- end }}

{{/* RHBK */}}
{{- define "rhbk-datagrid.rhbkLabels" -}}
{{ include "rhbk-datagrid.labels" . }}
{{ include "rhbk-datagrid.rhbkSelectorLabels" . }}
{{- end }}

{{- define "rhbk-datagrid.rhbkSelectorLabels" -}}
app.kubernetes.io/name: {{ include "rhbk-datagrid.rhbk" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: keycloak
{{- end }}

{{/* Data Grid */}}
{{- define "rhbk-datagrid.datagridLabels" -}}
{{ include "rhbk-datagrid.labels" . }}
{{ include "rhbk-datagrid.datagridSelectorLabels" . }}
{{- end }}

{{- define "rhbk-datagrid.datagridSelectorLabels" -}}
app.kubernetes.io/name: {{ include "rhbk-datagrid.datagrid" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: datagrid
{{- end }}

{{/* PostgreSQL */}}
{{- define "rhbk-datagrid.postgresqlLabels" -}}
{{ include "rhbk-datagrid.labels" . }}
{{ include "rhbk-datagrid.postgresqlSelectorLabels" . }}
{{- end }}

{{- define "rhbk-datagrid.postgresqlSelectorLabels" -}}
app.kubernetes.io/name: {{ include "rhbk-datagrid.postgresql" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: postgresql
{{- end }}

{{/*
JDBC URL for PostgreSQL.
*/}}
{{- define "rhbk-datagrid.jdbcUrl" -}}
jdbc:postgresql://{{ include "rhbk-datagrid.postgresql" . }}:5432/{{ .Values.postgresql.credentials.database }}
{{- end }}

{{/*
Data Grid DNS query for JGroups DNS_PING (headless service FQDN).
*/}}
{{- define "rhbk-datagrid.datagridDnsQuery" -}}
{{ include "rhbk-datagrid.datagridHeadless" . }}.{{ .Release.Namespace }}.svc.cluster.local
{{- end }}
