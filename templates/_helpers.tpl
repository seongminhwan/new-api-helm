{{/*
Expand the name of the chart.
*/}}
{{- define "new-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "new-api.fullname" -}}
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
{{- define "new-api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "new-api.labels" -}}
helm.sh/chart: {{ include "new-api.chart" . }}
{{ include "new-api.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "new-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "new-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Master selector labels
*/}}
{{- define "new-api.masterSelectorLabels" -}}
{{ include "new-api.selectorLabels" . }}
app.kubernetes.io/component: master
{{- end }}

{{/*
Slave selector labels
*/}}
{{- define "new-api.slaveSelectorLabels" -}}
{{ include "new-api.selectorLabels" . }}
app.kubernetes.io/component: slave
{{- end }}

{{/*
MySQL labels
*/}}
{{- define "new-api.mysql.labels" -}}
{{ include "new-api.labels" . }}
app.kubernetes.io/component: mysql
{{- end }}

{{/*
MySQL selector labels
*/}}
{{- define "new-api.mysql.selectorLabels" -}}
{{ include "new-api.selectorLabels" . }}
app.kubernetes.io/component: mysql
{{- end }}

{{/*
Redis labels
*/}}
{{- define "new-api.redis.labels" -}}
{{ include "new-api.labels" . }}
app.kubernetes.io/component: redis
{{- end }}

{{/*
Redis selector labels
*/}}
{{- define "new-api.redis.selectorLabels" -}}
{{ include "new-api.selectorLabels" . }}
app.kubernetes.io/component: redis
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "new-api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "new-api.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate secrets
*/}}
{{- define "new-api.sessionSecret" -}}
{{- if .Values.config.session.secret }}
{{- .Values.config.session.secret }}
{{- else }}
{{- randAlphaNum 32 }}
{{- end }}
{{- end }}

{{- define "new-api.cryptoSecret" -}}
{{- if .Values.config.crypto.secret }}
{{- .Values.config.crypto.secret }}
{{- else }}
{{- randAlphaNum 32 }}
{{- end }}
{{- end }}

{{- define "new-api.mysql.rootPassword" -}}
{{- if .Values.mysql.auth.rootPassword }}
{{- .Values.mysql.auth.rootPassword }}
{{- else }}
{{- randAlphaNum 16 }}
{{- end }}
{{- end }}

{{- define "new-api.mysql.password" -}}
{{- if .Values.mysql.auth.password }}
{{- .Values.mysql.auth.password }}
{{- else }}
{{- randAlphaNum 16 }}
{{- end }}
{{- end }}

{{- define "new-api.redis.password" -}}
{{- if .Values.redis.auth.password }}
{{- .Values.redis.auth.password }}
{{- else }}
{{- randAlphaNum 16 }}
{{- end }}
{{- end }}

{{/*
MySQL connection string
*/}}
{{- define "new-api.mysql.connectionString" -}}
{{- if .Values.mysql.enabled }}
{{- printf "%s:%s@tcp(%s-mysql:%d)/%s" .Values.mysql.auth.username (include "new-api.mysql.password" .) (include "new-api.fullname" .) (.Values.mysql.service.port | int) .Values.mysql.auth.database }}
{{- else }}
{{- printf "%s:%s@tcp(%s:%d)/%s" .Values.mysql.external.username .Values.mysql.external.password .Values.mysql.external.host (.Values.mysql.external.port | int) .Values.mysql.external.database }}
{{- end }}
{{- end }}

{{/*
Redis connection string
*/}}
{{- define "new-api.redis.connectionString" -}}
{{- if .Values.redis.enabled }}
{{- if .Values.redis.auth.enabled }}
{{- printf "redis://default:%s@%s-redis:%d" (include "new-api.redis.password" .) (include "new-api.fullname" .) (.Values.redis.service.port | int) }}
{{- else }}
{{- printf "redis://%s-redis:%d" (include "new-api.fullname" .) (.Values.redis.service.port | int) }}
{{- end }}
{{- else }}
{{- if .Values.redis.external.password }}
{{- printf "redis://default:%s@%s:%d/%d" .Values.redis.external.password .Values.redis.external.host (.Values.redis.external.port | int) (.Values.redis.external.database | int) }}
{{- else }}
{{- printf "redis://%s:%d/%d" .Values.redis.external.host (.Values.redis.external.port | int) (.Values.redis.external.database | int) }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Image name
*/}}
{{- define "new-api.image" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.newapi.image.registry }}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry .Values.newapi.image.repository (.Values.newapi.image.tag | default .Chart.AppVersion) }}
{{- else }}
{{- printf "%s:%s" .Values.newapi.image.repository (.Values.newapi.image.tag | default .Chart.AppVersion) }}
{{- end }}
{{- end }}

{{/*
MySQL image name
*/}}
{{- define "new-api.mysql.image" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.mysql.image.registry }}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry .Values.mysql.image.repository .Values.mysql.image.tag }}
{{- else }}
{{- printf "%s:%s" .Values.mysql.image.repository .Values.mysql.image.tag }}
{{- end }}
{{- end }}

{{/*
Redis image name
*/}}
{{- define "new-api.redis.image" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.redis.image.registry }}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry .Values.redis.image.repository .Values.redis.image.tag }}
{{- else }}
{{- printf "%s:%s" .Values.redis.image.repository .Values.redis.image.tag }}
{{- end }}
{{- end }}

{{/*
Storage class
*/}}
{{- define "new-api.storageClass" -}}
{{- if .Values.global.storageClass }}
{{- .Values.global.storageClass }}
{{- else }}
{{- .storageClass }}
{{- end }}
{{- end }}