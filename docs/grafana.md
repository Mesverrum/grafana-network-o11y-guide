# Explore queries

[← README](../README.md)

Prometheus (Grafana Cloud):

```promql
count by (device_name, snmp_group) (snmp_CPU{job="alloy-snmp"})
count by (snmp_tier) (up{job="alloy-snmp"})
count(alloy_network_io_by_flow_bytes{integration="alloy-netflow"})
```

Interface bps (true counters — use `rate()`):

```promql
rate(snmp_ifHCInOctets{device_name="leaf1"}[$__rate_interval]) * 8
```

Loki:

```logql
{service_name="alloy-snmptrap"}
{service_name="alloy-syslog"}
```

There is no `kentik_snmp_DeviceMetrics` and no `kentik_snmp_CPU` on this path.
