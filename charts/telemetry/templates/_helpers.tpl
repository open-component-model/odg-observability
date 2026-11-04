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
{{/*
Service name of the otel collector subchart. Use the pinned fullnameOverride so the
DataSink endpoint survives odg-core's release-name-free `helm template`.
*/}}
{{- define "telemetry.collectorServiceName" -}}
{{- index .Values "opentelemetry-collector" "fullnameOverride" -}}
{{- end }}

{{/*
DaemonSet pod-name prefix used by receiver filelog.exclude in collector-config.yaml.
Matches the subchart's pods under our values.yaml `fullnameOverride`, independent of
helm's release name (odg-core renders `helm template` with none).
*/}}
{{- define "telemetry.collectorDaemonSetPrefix" -}}
{{- printf "%s-agent-" (index .Values "opentelemetry-collector" "fullnameOverride") | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Cluster identity OTTL statements (resource context), shared by logs and traces.
Gardener: KUBERNETES_SERVICE_HOST = api.<shoot>.<project>.internal... -> "<project>/<shoot>".
Other clusters keep the raw value. Environment: values.environment, else the
odg-name label (pod first, then owning deployment/statefulset).
*/}}
{{- define "telemetry.clusterIdentityStatements" -}}
- set(resource.attributes["k8s.cluster.endpoint"], "${env:KUBERNETES_SERVICE_HOST}")
- set(resource.attributes["k8s.cluster.name"], resource.attributes["k8s.cluster.endpoint"])
- replace_pattern(resource.attributes["k8s.cluster.name"], "^api\\.([^.]+)\\.([^.]+)\\..*$", "$$2/$$1")
- set(resource.attributes["odg.instance"], resource.attributes["odg.instance.owner"]) where resource.attributes["odg.instance"] == nil and resource.attributes["odg.instance.owner"] != nil
- delete_key(resource.attributes, "odg.instance.owner")
- set(resource.attributes["deployment.environment.name"], resource.attributes["odg.instance"]) where resource.attributes["odg.instance"] != nil
{{- with .Values.environment }}
- set(resource.attributes["deployment.environment.name"], {{ . | quote }})
{{- end }}
{{- end }}
