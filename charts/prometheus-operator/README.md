# prometheus-operator chart

Umbrella chart for the ODG observability stack:

- **prometheus-operator** (templated here, CRDs under `crds/`)
- **kube-state-metrics** (vendored subchart, `charts/kube-state-metrics-*.tgz`)
- **perses** (vendored subchart, `charts/perses-*.tgz`, aliased `perses-app`) — dashboards UI
  - `perses.enabled: false` by default in values.yaml

Perses is installed without its operator: it has no CRDs; dashboards and datasources are
plain ConfigMaps labeled `perses.dev/resource: "true"` in the release namespace, which the
perses sidecar copies into its provisioning folder. See [`dashboards/README.md`](dashboards/README.md)
for the dashboard workflow (UI as scratchpad, git as source of truth).

## Bumping vendored subcharts

```sh
cd charts/prometheus-operator
rm charts/<subchart>-*.tgz
helm pull <repo>/<subchart> --version <version> -d charts/
# update the version in Chart.yaml, then:
helm dependency update .
```

(see the comment block in `Chart.yaml` for the exact repo coordinates per subchart)

### perses is patched after pulling

> `helm dependency update` re-downloads the pristine upstream tgz and wipes the patch —
> always re-run the script after it, or patch the tgz after any dependency update.

The vendored `perses-*.tgz` is not byte-identical to upstream. Upstream assembles its
image in `templates/statefulset.yaml` as `{{ .Values.image.registry }}/{{ .Values.image.name }}:...`
— incompatible with OCM's flat `host/path/image` relocation format. After pulling a new
version (Renovate postUpgradeTask), re-apply the patch:

```sh
./scripts/patch-perses-chart.sh charts/prometheus-operator/charts/perses-<version>.tgz
```

The script swaps the two inline image lines for `{{ include "perses-app.image" . }}` /
`"perses-app.sidecar.image"` (resolved by the chart's `templates/helpers/_odg.tpl`, which
consumes an optional flat `image.repository` + `image.tag` and falls back to the upstream
registry/name/version assembly otherwise), and extends `values.schema.json` with the new
keys. It exits non-zero if upstream's template changed shape, so bumps can't silently
skip it.
