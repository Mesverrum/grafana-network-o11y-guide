# Dashboards

[← README](../README.md)

## Import

In Grafana Cloud:

1. Left menu → **Dashboards** → **New** → **Import**
2. Upload a JSON file from the `dashboards/` folder in this repo
3. Pick your Prometheus and Loki data sources when asked
4. Open the dashboard and set the time range (last 1 hour is fine)

If JSON is not in the folder yet, use [grafana.md](grafana.md) in **Explore** until the exports land.

| Short name | Title | What it is for |
|------------|-------|----------------|
| A0 | Architecture | Picture of the collector path |
| A1 | Health | Is Alloy scraping / receiving flow and events? |
| A2 | Flow Summary | Conversations and rates |
| A3 | Device Summary | All devices: CPU, memory, BGP, alerts |
| A4 | Device Details | One device, tabbed (interfaces, routing, …) |

Traps in Loki: `{service_name="alloy-snmptrap"}`. Syslog: `{service_name="alloy-syslog"}`.

**Tabs:** Device Details is a tabbed dashboard. After you import it, do not “Save as” through old share/export tricks that flatten it. If tabs disappear and you get one long page, import the JSON again.

## Queries the dashboards use

You can paste these in Explore to debug a blank panel.

| What you want | Query idea |
|---------------|------------|
| Device list | `snmp_CPU` (one series per device) |
| Memory % | `device:snmp_MemoryUtilization:percent` when recording rules are installed; otherwise vendor memory OIDs |
| Interface bits/s | `rate(snmp_ifHCInOctets[$__rate_interval]) * 8` |
| Flow bits/s | `rate(alloy_network_io_by_flow_bytes{integration="alloy-netflow"}[5m])` |

These SNMP and flow series are **increasing counters**. Do not convert them with `* 8 / 60` (that pattern is for a different collector that sent 60-second deltas).

On tables, hide scrape-internal labels (`instance`, `service_instance_id`, `sysObjectID`) so you see `device_name` and interface names.

Device identity label is always `device_name`. Site / group is `snmp_group`.
