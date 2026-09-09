# Notes for editing dashboards

Optional. For people changing the A0–A4 boards, not required to get data flowing.

- Metric names start with `snmp_` (devices) or `alloy_network_io_by_flow_` (flow).
- Device label: `device_name`. Site / group label: `snmp_group`.
- Interface and flow rates use `rate(...)`, not divide-by-60.

Design-pattern writeups will land here when the boards are exported.
