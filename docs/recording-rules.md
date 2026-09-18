# Recording rules (interface util / error %)

[← README](../README.md)

Import the dashboards first ([dashboards.md](dashboards.md)). **Health**, raw `snmp_CPU`, and `rate(snmp_ifHCInOctets)` work with no extra step.

A few Device Summary / Device Details panels look for **precomputed** series (colon names). Those come from Grafana-managed recording rules, not from Alloy. You import the YAML **in Grafana Cloud** — not onto the poller.

| Recorded name | What the panel shows |
|---------------|----------------------|
| `device:snmp_MemoryUtilization:percent` | Memory used % |
| `if:snmp_ifHCInOctets:rate5m` / `Out` | Interface bytes/s |
| `if:snmp_IfInUtilization:percent` / `Out` | Link util vs `ifHighSpeed` |
| `if:snmp_ifInErrors:rate5m` / `Out` | Errors/s (cold scrape) |
| `if:snmp_ifInErrorPercent:percent` / `Out` | Errors / unicast packets |

File: [`grafana/recording-rules.yaml`](../grafana/recording-rules.yaml).

The OpenTelemetry `glc_` token **cannot** do this import. Use your Grafana Cloud login (UI) or a service-account token with **Alerting: Write**.

## Install — Grafana Cloud UI (usual path)

1. Open **your** stack (the same one as `GC_OTLP_*`).
2. Left menu → **Alerting** → **Alert rules**.
3. **More** (top right) → **Import to Grafana-managed rules**.
4. Import source: **Prometheus YAML file**.
5. Upload [`grafana/recording-rules.yaml`](../grafana/recording-rules.yaml).
6. Data source: this stack’s Prometheus (`grafanacloud-prom` or the same UID you picked on the dashboards).
7. Target data source for recording rules: the **same** Prometheus (leave default if the UI already shows it).
8. Folder: create or pick **Network O11y** (any folder you can see in Alerting is fine).
9. Import. Wait 1–2 minutes, then refresh Device Details.

Menu names move slightly. If you do not see **Import to Grafana-managed rules**, look under **Alerting** → **More**, or use the [script](#install--script) below.

You should see two groups:

- `alloy-snmp.composites` (1m) — memory %, octets/s, link util
- `alloy-snmp.composites.cold` (5m) — errors/s and error %

## Install — script

Needs `GRAFANA_URL` (the dashboard URL, e.g. `https://mystack.grafana.net`) and a **Grafana** token with Alerting write — not the OTLP key.

```
export GRAFANA_URL=https://<your-stack>.grafana.net
export GRAFANA_TOKEN=glsa_…   # stack service account, Alerting: Write
python3 scripts/import-recording-rules.py
```

Optional: `--datasource-uid grafanacloud-prom` `--folder-uid network-o11y`. `--dry-run` prints the resolved UIDs and does not write.

## Check they landed

Explore → Prometheus, time range **Last 15 minutes**:

```promql
count(device:snmp_MemoryUtilization:percent)
count(if:snmp_ifHCInOctets:rate5m)
```

Zero series after a few minutes usually means the import went to a different stack, the rule is paused, or SNMP is not scraping yet (`snmp_CPU` would also be empty).

Alloy only exports the raw `snmp_*` counters. Do not copy this YAML onto the poller.
