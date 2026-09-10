# Explore queries (only if a dashboard is empty)

[← README](../README.md)

Bring-up is **import the dashboards** ([dashboards.md](dashboards.md)). Use Explore only to debug a blank panel.

**Explore** is Grafana’s scratch query page (compass icon on the left).

1. Open your Grafana Cloud stack in the browser.
2. Click **Explore**.
3. Top left: choose the data source — **Prometheus** / **grafanacloud-…prom** for metrics, **Loki** / **grafanacloud-…logs** for traps and syslog.
4. Time picker (top right): **Last 15 minutes**.
5. Paste a query below → **Run query**.

If the list of data sources is empty, the Cloud stack is new or your user cannot see them — fix that in Cloud before debugging Alloy.

## Metrics (Prometheus)

Devices Alloy is polling:

```promql
count by (device_name, snmp_group) (snmp_CPU{job="alloy-snmp"})
```

Which poll interval is succeeding (`up` is 1 when a scrape works):

```promql
count by (snmp_tier) (up{job="alloy-snmp"})
```

Flow records arriving:

```promql
count(alloy_network_io_by_flow_bytes{integration="alloy-netflow"})
```

Interface bits per second (replace `leaf1` with a `device_name` from the first query):

```promql
rate(snmp_ifHCInOctets{device_name="leaf1"}[$__rate_interval]) * 8
```

`rate()` is required: the metric counts octets and only goes up.

## Logs (Loki)

Traps:

```logql
{service_name="alloy-snmptrap"}
```

Syslog:

```logql
{service_name="alloy-syslog"}
```

No lines usually means the device is still sending to an old collector IP or port. Check the device config against the poller’s management address.
