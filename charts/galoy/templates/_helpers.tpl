{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "galoy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified api name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "galoy.api.fullname" -}}
{{- default "api" .Values.galoy.api.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified admin name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "galoy.admin.fullname" -}}
{{- default "graphql-admin" .Values.galoy.admin.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified websocket name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "galoy.websocket.fullname" -}}
{{- default "websocket" .Values.galoy.websocket.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified exporter name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "galoy.exporter.fullname" -}}
{{- default "exporter" .Values.galoy.exporter.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified trigger name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "galoy.trigger.fullname" -}}
{{- default "trigger" .Values.galoy.trigger.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified consent name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "galoy.consent.fullname" -}}
{{- default "consent" .Values.galoy.consent.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified api keys name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "galoy.apiKeys.fullname" -}}
{{- default "api-keys" .Values.galoy.apiKeys.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified notifications name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "galoy.notifications.fullname" -}}
{{- default "notifications" .Values.galoy.notifications.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
CronJob name
*/}}
{{- define "galoy.cron.jobname" -}}
{{- printf "%s-cronjob" .Release.Name -}}
{{- end -}}

{{/*
Mongo Backup CronJob name
*/}}
{{- define "galoy.mongoBackupCron.jobname" -}}
{{- printf "%s-mongo-backup" .Release.Name -}}
{{- end -}}

{{/*
Migration Job name
*/}}
{{- define "galoy.migration.jobname" -}}
{{- printf "%s-mongodb-migrate-%d" .Release.Name .Release.Revision -}}
{{- end -}}

{{/*
Pre-Migration Job name
*/}}
{{- define "galoy.preMigration.jobname" -}}
{{- printf "%s-pre-mongodb-migrate-%d" .Release.Name .Release.Revision -}}
{{- end -}}

{{/*
Config name
*/}}
{{- define "galoy.config.name" -}}
{{- printf "%s-config" .Release.Name -}}
{{- end -}}

{{/*
Return Galoy environment variables for MongoDB configuration
*/}}
{{- define "galoy.mongodb.env" -}}
- name: MONGODB_CON
  valueFrom:
    secretKeyRef:
      name: {{ .Values.mongodb.auth.connectionStringExistingSecret }}
      key: mongodb-con
{{ if eq .Values.mongodb.architecture "replicaset" }}
- name: MONGODB_ADDRESS
  value: "{{ range until (.Values.mongodb.replicaCount | int) }}
  {{- printf "galoy-mongodb-%d.galoy-mongodb-headless" . -}}
  {{- if lt . (sub $.Values.mongodb.replicaCount 1 | int) -}},{{- end -}}
  {{ end }}"
- name: MONGODB_USER
  value: {{ index .Values.mongodb.auth.usernames 0 | quote }}
- name: MONGODB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.mongodb.auth.existingSecret }}
      key: mongodb-passwords
{{ else if eq .Values.mongodb.architecture "standalone" }}
- name: MONGODB_ADDRESS
  value: "galoy-mongodb"
- name: MONGODB_USER
  value: {{ index .Values.mongodb.auth.usernames 0 | quote }}
- name: MONGODB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.mongodb.auth.existingSecret }}
      key: mongodb-passwords
{{ end }}
{{- end -}}

{{/*
Return Galoy environment variables for LND 1 configuration
*/}}
{{- define "galoy.lnd1.env" -}}
- name: LND1_DNS
  value: {{ .Values.galoy.lnd1.dns | quote }}
- name: LND1_MACAROON
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.lnd1.credentialsExistingSecret.name }}
      key: {{ .Values.galoy.lnd1.credentialsExistingSecret.macaroon_key }}
- name: LND1_TLS
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.lnd1.credentialsExistingSecret.name }}
      key: {{ .Values.galoy.lnd1.credentialsExistingSecret.tls_key }}
- name: LND1_PUBKEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.lnd1.pubkeyExistingSecret.name }}
      key: {{ .Values.galoy.lnd1.pubkeyExistingSecret.key }}
- name: LND1_CREDS_CHECKSUM
  value: {{ .Values.galoy.lnd1.credsChecksum | default "" }}
{{- end -}}
{{/*
Return Galoy environment variables for LND 2 configuration
*/}}
{{- define "galoy.lnd2.env" -}}
- name: LND2_DNS
  value: {{ .Values.galoy.lnd2.dns | quote }}
- name: LND2_MACAROON
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.lnd2.credentialsExistingSecret.name }}
      key: {{ .Values.galoy.lnd2.credentialsExistingSecret.macaroon_key }}
- name: LND2_TLS
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.lnd2.credentialsExistingSecret.name }}
      key: {{ .Values.galoy.lnd2.credentialsExistingSecret.tls_key }}
- name: LND2_PUBKEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.lnd2.pubkeyExistingSecret.name }}
      key: {{ .Values.galoy.lnd2.pubkeyExistingSecret.key }}
- name: LND2_CREDS_CHECKSUM
  value: {{ .Values.galoy.lnd2.credsChecksum | default "" }}
{{- end -}}

{{/*
Define kratos env vars
*/}}
{{- define "galoy.kratos.env" -}}
- name: KRATOS_MASTER_USER_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.kratos.existingSecret.name }}
      key: {{ .Values.galoy.kratos.existingSecret.master_user_password }}
- name: KRATOS_PG_CON
  valueFrom:
    secretKeyRef:
      name: {{ .Values.kratos.secret.nameOverride | default "galoy-kratos" }}
      key: dsn
- name: KRATOS_PUBLIC_API
  value: {{ .Values.galoy.kratos.publicApiUrl | quote }}
- name: KRATOS_ADMIN_API
  value: {{ .Values.galoy.kratos.adminApiUrl | quote }}
{{- end -}}

{{- define "galoy.bria.env" -}}
- name: BRIA_HOST
  value: {{ .Values.galoy.bria.host | quote }}
- name: BRIA_PORT
  value: {{ .Values.galoy.bria.port | quote }}
- name: BRIA_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.bria.apiKeyExistingSecret.name | quote }}
      key: {{ .Values.galoy.bria.apiKeyExistingSecret.key | quote }}
{{- end -}}

{{/*
Return Galoy environment variables for Redis configuration
*/}}
{{- define "galoy.redis.env" -}}
- name: REDIS_MASTER_NAME
  value: {{ .Values.redis.sentinel.masterSet | quote }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.redis.auth.existingSecret | quote }}
      key: {{ .Values.redis.auth.existingSecretPasswordKey | quote }}
{{ range until (.Values.redis.replica.replicaCount | int) }}
- name: {{ printf "REDIS_%d_DNS" . }}
  value: {{ printf "galoy-redis-node-%d.galoy-redis-headless" . | quote }}
{{ end }}
{{- end -}}

{{/*
Return Galoy environment variables for Twilio
*/}}
{{- define "galoy.twilio.env" -}}
- name: TWILIO_VERIFY_SERVICE_ID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.twilioExistingSecret.name }}
      key: {{ .Values.galoy.twilioExistingSecret.verify_service_id }}
- name: TWILIO_ACCOUNT_SID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.twilioExistingSecret.name }}
      key: {{ .Values.galoy.twilioExistingSecret.account_sid_key }}
- name: TWILIO_AUTH_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.twilioExistingSecret.name }}
      key: {{ .Values.galoy.twilioExistingSecret.auth_token_key }}
- name: TWILIO_MESSAGING_SERVICE_ID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.twilioExistingSecret.name }}
      key: {{ .Values.galoy.twilioExistingSecret.messaging_service_id }}
- name: TWILIO_WELCOME_CONTENT_SID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.twilioExistingSecret.name }}
      key: {{ .Values.galoy.twilioExistingSecret.welcome_content_sid }}
{{- end -}}

{{/*
Return Galoy environment variables for Prelude
*/}}
{{- define "galoy.prelude.env" -}}
- name: PRELUDE_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.preludeExistingSecret.name }}
      key: {{ .Values.galoy.preludeExistingSecret.api_key }}
{{- end -}}

{{/*
Return Galoy environment variables for Geetest
*/}}
{{- define "galoy.geetest.env" -}}
- name: GEETEST_ID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.geetestExistingSecret.name }}
      key: {{ .Values.galoy.geetestExistingSecret.id_key }}
- name: GEETEST_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.geetestExistingSecret.name }}
      key: {{ .Values.galoy.geetestExistingSecret.secret_key }}
{{- end -}}

{{- define "galoy.telegram.env" -}}
- name: TELEGRAM_PASSPORT_PRIVATE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.telegramExistingSecret.name }}
      key: {{ .Values.galoy.telegramExistingSecret.private_key }}
- name: TELEGRAM_BOT_API_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ .Values.galoy.telegramExistingSecret.name }}
      key: {{ .Values.galoy.telegramExistingSecret.api_token_key }}
{{- end -}}

# TODO: Remove this once https://github.com/apollographql/router/issues/4002 is resolved
# This is copied from https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_tplvalues.tpl
{{- define "common.tplvalues.render" -}}
{{- $value := typeIs "string" .value | ternary .value (.value | toYaml) }}
{{- if contains "{{" (toJson .value) }}
  {{- if .scope }}
      {{- tpl (cat "{{- with $.RelativeScope -}}" $value "{{- end }}") (merge (dict "RelativeScope" .scope) .context) }}
  {{- else }}
    {{- tpl $value .context }}
  {{- end }}
{{- else }}
    {{- $value }}
{{- end }}
{{- end -}}
