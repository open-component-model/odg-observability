#!/usr/bin/env bash
# Re-applies the ODG vendoring patch to the vendored perses chart after a version bump
# (intended as Renovate postUpgradeTask). Why the patch exists:
# https://github.com/perses/helm-charts — upstream statefulset.yaml inlines
#   image: "{{ .Values.image.registry }}/{{ .Values.image.name }}:..."
# which is incompatible with OCM's flat "host/path/image" repository format. We replace
# the two inline image lines with {{ include ... }} calls, add helpers/_odg.tpl
# implementing them, and extend values.schema.json with the new flat keys.
#
# Usage: ./scripts/patch-perses-chart.sh charts/prometheus-operator/charts/perses-<version>.tgz
set -euo pipefail

TARBALL="$1"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

tar xzf "$TARBALL" -C "$WORK"

python3 - "$WORK/perses" <<'PYEOF'
import json, sys
root = sys.argv[1]

# --- 1. statefulset.yaml: replace inline image assembly with helper calls
p = f'{root}/templates/statefulset.yaml'
s = open(p).read()

old_main = '''        {{- if .Values.image.digest }}
        image: "{{ .Values.image.registry }}/{{ .Values.image.name }}:{{ .Values.image.version | default .Chart.AppVersion }}@{{ .Values.image.digest }}"
        {{- else }}
        image: "{{ .Values.image.registry }}/{{ .Values.image.name }}:{{ .Values.image.version | default .Chart.AppVersion }}"
        {{- end }}'''
new_main = '''        image: {{ include "perses-app.image" . | quote }}'''

old_sidecar = '''        {{- if .Values.sidecar.image.digest }}
        image: "{{ .Values.sidecar.image.registry | default .Values.image.registry }}/{{ .Values.sidecar.image.repository }}:{{ .Values.sidecar.image.tag }}@{{ .Values.sidecar.image.digest }}"
        {{- else }}
        image: "{{ .Values.sidecar.image.registry | default .Values.image.registry }}/{{ .Values.sidecar.image.repository }}:{{ .Values.sidecar.image.tag }}"
        {{- end }}'''
new_sidecar = '''        image: {{ include "perses-app.sidecar.image" . | quote }}'''

for old, new, label in [(old_main, new_main, 'main image'), (old_sidecar, new_sidecar, 'sidecar image')]:
    if new in s:
        print(f'{label}: already patched, skipping')
        continue
    assert old in s, f'{label}: upstream template changed — patch no longer applies, review manually'
    s = s.replace(old, new)
open(p, 'w').write(s)

# --- 2. values.schema.json: allow the new flat keys
p = f'{root}/values.schema.json'
schema = json.load(open(p))
img = schema['properties']['image']['properties']
# null allowed: OCM sets them at release, values.yaml keeps them ~ by default
img.setdefault('repository', {'type': ['string', 'null']})
img.setdefault('tag', {'type': ['string', 'null']})
sc_img = schema['properties']['sidecar']['properties']['image']['properties']
# sidecar already has flat-ish repository/tag; nothing to add
json.dump(schema, open(p, 'w'), indent=2)
print('schema: image.repository/image.tag allowed')
PYEOF

# --- 3. helpers/_odg.tpl
mkdir -p "$WORK/perses/templates/helpers"
cat > "$WORK/perses/templates/helpers/_odg.tpl" <<'TPL'
{{/*
ODG vendoring patch — see scripts/patch-perses-chart.sh. Overrides image assembly so
OCM's flat "host/path/image" + tag works:
  image.repository + image.tag set        → used verbatim (OCM relocation)
  else image.registry/name/version        → upstream split assembly (defaults)
Sidecar uses sidecar.image.repository/tag if repository is a full host/path string
(contains "/"), else the chart's registry+repository:tag.
*/}}
{{- define "perses-app.image" -}}
{{- $img := .Values.image -}}
{{- if and $img.repository $img.tag }}
{{- if $img.digest }}{{ $img.repository }}:{{ $img.tag }}@{{ $img.digest }}{{ else }}{{ $img.repository }}:{{ $img.tag }}{{ end }}
{{- else if $img.digest -}}
{{ $img.registry }}/{{ $img.name }}:{{ $img.version | default .Chart.AppVersion }}@{{ $img.digest }}
{{- else -}}
{{ $img.registry }}/{{ $img.name }}:{{ $img.version | default .Chart.AppVersion }}
{{- end }}
{{- end }}

{{- define "perses-app.sidecar.image" -}}
{{- $img := .Values.sidecar.image -}}
{{- if and $img.repository $img.tag (regexMatch "/" $img.repository) }}
{{- if $img.digest }}{{ $img.repository }}:{{ $img.tag }}@{{ $img.digest }}{{ else }}{{ $img.repository }}:{{ $img.tag }}{{ end }}
{{- else if $img.digest -}}
{{ $img.registry | default $.Values.image.registry }}/{{ $img.repository }}:{{ $img.tag }}@{{ $img.digest }}
{{- else -}}
{{ $img.registry | default $.Values.image.registry }}/{{ $img.repository }}:{{ $img.tag }}
{{- end }}
{{- end }}
TPL

# --- 4. re-tar in place
tar czf "$TARBALL" -C "$WORK" perses
echo "patched: $TARBALL"
