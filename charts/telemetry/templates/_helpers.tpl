{{/*
Labels for resources this chart owns (DataSink, Metric CRs, NetworkPolicies).
Distinct from the opentelemetry-collector subchart's labels (different
part-of/instance semantics; ours describe the whole telemetry stack).
*/}}
{{- define "telemetry.labels" -}}
app.kubernetes.io/part-of: telemetry
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end }}

{{/*
Name of the collector Service created by the opentelemetry-collector subchart.
Subchart fullname = "<release>-opentelemetry-collector" (nameOverride unset,
no fullnameOverride). Exported via service.enabled=true. Everything that needs
to reach the collector (DataSink, docs) should use this, not a hardcoded name.
*/}}
{{- define "telemetry.collectorServiceName" -}}
{{- printf "%s-opentelemetry-collector" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}
