# First-time problems

[← README](../README.md)

Work top to bottom. Confirm on the imported dashboards (Device Summary, Health) and on the local Alloy page http://127.0.0.1:12345 (on the poller) before guessing in Explore.

### 1. Log says `unknown component "discovery.snmp"`

You are still running the official package. Follow [install-alloy.md](../docs/install-alloy.md): replace `/usr/bin/alloy` and set `CUSTOM_ARGS="--stability.level=experimental"` in `/etc/default/alloy`. Then `sudo systemctl restart alloy`.

On a laptop Compose setup: you never built `alloy-network:dev`, or `.env` has the wrong `ALLOY_IMAGE`.

### 2. Grafana shows 401 / 404, or nothing arrives

`GC_OTLP_URL`, `GC_OTLP_ACCOUNT`, and `GC_OTLP_KEY` must all be from **the same** Grafana Cloud stack (same region). How to copy them: [grafana-cloud-otlp.md](../docs/grafana-cloud-otlp.md). They live in `/etc/default/alloy` (or `.env` for Compose). Do not open the OTLP URL in a browser.

After editing that file: `sudo systemctl restart alloy`.

### 3. Discovery finds zero devices

- `/etc/alloy/auths.yml` missing, or `chmod` not readable by the `alloy` service user
- Config says `auths = ["public_v2", "campus_v2"]` but those names are missing as keys in the file
- Community / v3 on the device does not match the file — prove it with [snmp.md](snmp.md)

### 4. `snmpget` from the poller fails

Alloy will fail the same way. Management ACL, wrong VRF, device SNMP disabled, or wrong community. Fix reachability first.

Docker on a laptop: the container is often on a bridge that cannot see the campus management network. Use a poller on that network, or `network_mode: host` on Linux.

### 5. Alloy looks healthy locally, dashboards are empty

You are logged into a **different** Grafana Cloud stack than `GC_OTLP_*` on the poller. Check the browser URL vs the URL in `/etc/default/alloy`. On import, pick the Prometheus/Loki data sources that belong to **this** stack.

### 6. One panel is empty, others are not

The query on that panel may be wrong for this path. Optional: paste the panel query in Explore ([grafana.md](../docs/grafana.md)). Device inventory is `snmp_CPU` — there is no single `DeviceMetrics` metric.

### 7. Traps or syslog missing

On the device, the destination IP/port is still the old NMS. Sample ports: traps `11620`, syslog `1514`. If both a local config file *and* Fleet try to bind the same UDP port, one side loses — pick one listener.
