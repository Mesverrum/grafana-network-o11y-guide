# First-time problems

[← README](../README.md)

Work top to bottom. Confirm on the imported dashboards (Device Summary, Health) and on the local Alloy page http://127.0.0.1:12345 (on the poller) before guessing in Explore.

Default runtime is Compose. Host-service notes are in parentheses.

### 1. Container will not start, or log says `unknown component "discovery.snmp"`

```
docker compose logs --tail=80
```

- `.env` `ALLOY_IMAGE` is not `ghcr.io/mesverrum/alloy-network:v0.1.0` (or your compiled `alloy-network:dev`).
- You never pulled — `docker compose pull && docker compose up -d`.
- `alloy/config.alloy` is a **directory** (you ran Compose before copying the sample). `rm -rf alloy/config.alloy`, then `cp alloy/config.alloy.sample alloy/config.alloy`.
- Host service: you are still running `apt` Alloy. Follow [install-alloy.md](../docs/install-alloy.md#optional-run-as-a-host-service) and set `--stability.level=experimental`.

### 2. Grafana shows 401 / 404, or nothing arrives

`GC_OTLP_URL`, `GC_OTLP_ACCOUNT`, and `GC_OTLP_KEY` must all be from **the same** Grafana Cloud stack (same region). How to copy them: [grafana-cloud-otlp.md](../docs/grafana-cloud-otlp.md). They live in `.env` (or `/etc/default/alloy` on a host service). Do not open the OTLP URL in a browser.

After editing `.env`: `docker compose up -d --force-recreate`.

### 3. Discovery finds zero devices

- `alloy/auths.yml` missing (Compose mount is empty or a directory)
- Config says `auths = ["public_v2", "campus_v2"]` but those names are missing as keys in the file
- Community / v3 on the device does not match the file — prove it with [snmp.md](snmp.md)

### 4. `snmpget` from the poller fails

Alloy will fail the same way. Management ACL, wrong VRF, device SNMP disabled, or wrong community. Fix reachability first.

Docker Desktop on a laptop cannot see a campus management VLAN. Run Compose on a Linux host on that network (`network_mode: host` is already in `compose.yaml`).

### 5. Alloy looks healthy locally, dashboards are empty

You are logged into a **different** Grafana Cloud stack than `GC_OTLP_*` in `.env`. Check the browser URL vs that file. On import, pick the Prometheus/Loki data sources that belong to **this** stack.

### 6. One panel is empty, others are not

The query on that panel may be wrong for this path. Optional: paste the panel query in Explore ([grafana.md](../docs/grafana.md)). Device inventory is `snmp_CPU` — there is no single `DeviceMetrics` metric.

Health (A1) discovery counts need the sample’s **self-scrape** (`job="alloy"`, `discovery_snmp_*`). If you wrote your own River and omitted `prometheus.exporter.self`, those panels stay at zero while Device Summary still works.

Device Details **util % / error % / memory %** need [recording rules](../docs/recording-rules.md). Raw octets and `snmp_CPU` still work without them.

Flow Summary stays empty until a device exports NetFlow to `:2055` or sFlow to `:6344` (the sample listens on both). That is expected on an SNMP-only first pass.

### 7. Traps or syslog missing

On the device, the destination IP/port is still the old NMS. Sample ports: traps `11620`, syslog `1514` (not `:1620` / `:1515` unless you changed the config). If both a local config file *and* Fleet try to bind the same UDP port, one side loses — pick one listener.

Until you point a device at those ports, A1 event rows and Loki `{service_name="alloy-snmptrap"|"alloy-syslog"}` stay empty. That is not an OTLP failure.
