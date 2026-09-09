# Dashboards

[← README](../README.md)

Same UX as the ktranslate 00–04 pack, queries retargeted to Alloy names. JSON in `dashboards/` (import via Grafana Cloud → Dashboards → Import). Prefer the v2 manifest path for tabbed boards — do not `POST /api/dashboards/db` on TabsLayout (it flattens tabs).

| # | Title | What |
|---|-------|------|
| A0 | Architecture | How the collector is wired |
| A1 | Health | Scrape / flow / events — not ktranslate CHF |
| A2 | Flow Summary | `alloy_network_io_by_flow_bytes`, `rate()` |
| A3 | Device Summary | Fleet: CPU, memory, BGP, alerts |
| A4 | Device Details | Single device, tabs |

Traps: Loki `{service_name="alloy-snmptrap"}`. Syslog: `{service_name="alloy-syslog"}`.

Dashboard JSON will land here as the A0–A4 set is exported from the design-partner stack. Until then, the PromQL contract in [grafana.md](grafana.md) is enough to Explore.

## PromQL (operator patterns)

| Use | Avoid |
|-----|-------|
| `snmp_CPU`, `device:snmp_MemoryUtilization:percent` | `kentik_snmp_*` |
| `rate(snmp_ifHCInOctets[$__rate_interval]) * 8` or recording `if:snmp_ifHCInOctets:rate5m` | ktranslate `* 8 / 60` on Alloy counters |
| `rate(alloy_network_io_by_flow_bytes{integration="alloy-netflow"}[5m])` | `max_over_time` / `* 8 / 60` (that is the ktranslate gauge) |
| Hide scrape labels (`instance`, `service_instance_id`, `sysObjectID`) on tables | Dumping `format: table` with every label |

Device identity label is always `device_name`. Site bucket is `snmp_group`.
