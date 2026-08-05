{{- define "nodejs-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "nodejs-api.fullname" -}}
{{- default (include "nodejs-api.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
