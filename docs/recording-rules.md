# Recording rules (interface util / error %)

[← README](../README.md)

Import the dashboards first ([dashboards.md](dashboards.md)). **Device Summary**, **Health**, and raw `snmp_CPU` / `rate(snmp_ifHCInOctets)` work with no extra step.

A few Device Details panels look for **precomputed** series (colon names). Those come from Grafana-managed recording rules, not from Alloy:

| Recorded name | What the panel shows |
|---------------|----------------------|
| `device:snmp_MemoryUtilization:percent` | Memory used % |
| `if:snmp_ifHCInOctets:rate5m` / `Out` | Interface bytes/s |
| `if:snmp_IfInUtilization:percent` / `Out` | Link util vs `ifHighSpeed` |
| `if:snmp_ifInErrors:rate5m` / `Out` | Errors/s (cold scrape) |
| `if:snmp_ifInErrorPercent:percent` / `Out` | Errors / unicast packets |

File: [`grafana/recording-rules.yaml`](../grafana/recording-rules.yaml).

## Install on Grafana Cloud

1. Open your stack → **Alerting** → **Recording rules** (sometimes under **Alerting** → **More**).
2. Data source: this stack’s Prometheus / Mimir (the same one the dashboards use).
3. Create two groups (`alloy-snmp.composites` at 1m, `alloy-snmp.composites.cold` at 5m) and paste the `expr` blocks from the YAML — or use your stack’s YAML import if it is offered.
4. Wait one or two evaluation intervals, then refresh Device Details.

You do **not** put this YAML on the poller. Alloy only exports the raw `snmp_*` counters.
