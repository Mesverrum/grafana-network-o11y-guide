# Dashboard JSON

This is the bring-up check. In Grafana Cloud: **Dashboards → New → Import** → upload each file from this folder. Choose your Prometheus and Loki data sources. Open Device Summary and Health; data should already be arriving.

| File | Title |
|------|-------|
| [`a0-alloy-architecture.json`](a0-alloy-architecture.json) | A0. Alloy Architecture |
| [`a1-alloy-health.json`](a1-alloy-health.json) | A1. Alloy Health |
| [`a2-alloy-flow-summary.json`](a2-alloy-flow-summary.json) | A2. Alloy Flow Summary |
| [`a3-alloy-device-summary.json`](a3-alloy-device-summary.json) | A3. Alloy Device Summary |
| [`a4-alloy-device-details.json`](a4-alloy-device-details.json) | A4. Alloy Device Details |

These are Grafana **v2** manifests (they keep tabs). After import, Device Details / Health / Device Summary should still show tabs — not one long page. If tabs disappear, import the file again; do not “Save as” through old share/export.

All five share the tag `network-o11y` (the **Network O11y** dropdown).

See [docs/dashboards.md](../docs/dashboards.md).
