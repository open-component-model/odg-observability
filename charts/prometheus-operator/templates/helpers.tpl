{{- define "image" -}}
{{- if $.ref -}}
{{ $.ref }}
{{- else -}}
{{- if hasPrefix "sha256:" (required "$.tag is required" $.tag) -}}
{{ required "$.repository is required" $.repository }}@{{ required "$.tag is required" $.tag }}
{{- else -}}
{{ required "$.repository is required" $.repository }}:{{ required "$.tag is required" $.tag }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Override kube-state-metrics subchart image helper so OCM relocation uses the same flat
repository:tag format as the other images in this chart, instead of KSM's registry/repository:tag
split which is incompatible with OCM's .repository attribute (full host/path/image string).
When image.repository is set (by OCM), use it directly as the full host/path/image reference.
When unset, fall through to KSM's native registry+repository assembly so defaults still work.
*/}}
{{- define "kube-state-metrics.image" -}}
{{- $tag := default (printf "v%s" .Chart.AppVersion) .Values.image.tag -}}
{{- if .Values.image.repository -}}
  {{- if hasPrefix "sha256:" $tag -}}
{{ .Values.image.repository }}@{{ $tag }}
  {{- else -}}
{{ .Values.image.repository }}:{{ $tag }}
  {{- end -}}
{{- else if .Values.image.sha -}}
  {{- if .Values.global.imageRegistry -}}
{{- printf "%s/%s:%s@%s" .Values.global.imageRegistry "kube-state-metrics/kube-state-metrics" $tag .Values.image.sha -}}
  {{- else -}}
{{- printf "%s/%s:%s@%s" .Values.image.registry "kube-state-metrics/kube-state-metrics" $tag .Values.image.sha -}}
  {{- end -}}
{{- else -}}
  {{- if .Values.global.imageRegistry -}}
{{- printf "%s/%s:%s" .Values.global.imageRegistry "kube-state-metrics/kube-state-metrics" $tag -}}
  {{- else -}}
{{- printf "%s/%s:%s" .Values.image.registry "kube-state-metrics/kube-state-metrics" $tag -}}
  {{- end -}}
{{- end -}}
{{- end -}}
