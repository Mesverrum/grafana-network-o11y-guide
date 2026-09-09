# Words this guide uses

[← README](../README.md)

Written for network engineers. Skip any row you already know.

| Term | Meaning here |
|------|----------------|
| **Poller** | The Linux host that runs Alloy. It must reach device management IPs. |
| **Alloy** | Grafana’s collector: one program (`/usr/bin/alloy`) run by `systemctl`. |
| **systemd / systemctl** | How Linux starts the service. `sudo systemctl status alloy` / `restart alloy`. |
| **journalctl** | Service logs: `journalctl -u alloy -f`. |
| **Config file / `.alloy`** | Alloy’s config (Grafana calls the language *River*). Comments are `//`, not `#`. Samples in `alloy/`. |
| **Fork / network-snmp** | A copy of Alloy that already has SNMP discovery, traps, and flow. Not in `apt install alloy` yet. Install steps: [install-alloy.md](install-alloy.md). |
| **Docker / image** | A packaged build environment. You use it once to *compile* Alloy, then copy the program onto the poller. You are not required to run production Alloy in Docker. |
| **Grafana Cloud stack** | One Cloud environment (dashboards + metrics + logs). You pick it on [grafana.com](https://grafana.com) after login. |
| **Access policy / `glc_` token** | A machine password Grafana shows once. Create it on the stack’s **OpenTelemetry** tile or **Administration → Cloud access policies**. Click-by-click: [grafana-cloud-otlp.md](grafana-cloud-otlp.md). Not the password you type to log into the website. The metrics token is not automatically allowed to edit Fleet. |
| **OTLP** | How Alloy *pushes* data to Cloud (HTTPS). Three values from that same page: endpoint URL, instance ID, token. Not a website you browse. |
| **Explore** | Grafana’s ad-hoc query screen (compass icon). Pick **Prometheus** for metrics, **Loki** for trap/syslog logs. |
| **Prometheus / PromQL** | Metrics store and its query language. Example: `snmp_CPU`. |
| **Loki / LogQL** | Log store and its query language. Example: `{service_name="alloy-snmptrap"}`. |
| **Fleet Management** | Cloud UI that can push config to Alloy: **Connections → Collector → Fleet Management**. **No passwords here.** |
| **Pipeline** | The config document you edit in Fleet (CIDRs, ports, credential *names*). |
| **remotecfg** | The short snippet Cloud gives you when you “add collector.” Paste it on the poller so Alloy pulls the pipeline. |
| **Auth name** | A label such as `public_v2`. The community or v3 secret lives on the poller under that name. |
| **CIDR** | Prefix to scan, e.g. `10.0.0.0/24`, or one device `192.168.1.1/32`. |
| **Discovery** | Alloy SNMP-walks the CIDR, reads `sysObjectID`, and decides which OIDs to poll. |
| **Hot / cold / topology** | How often Alloy polls. Hot ≈ 60s (CPU, interface counters). Cold ≈ 5 minutes (names, errors). Topology ≈ 15 minutes (LLDP / BGP). Same idea as fast vs slow NMS polling. |
| **`device_name`** | Label meaning “which network device.” |
| **`snmp_group`** | Label for the discovery group you named (`hq`, `dc`) — a site or credential bucket, not your CMDB. |
| **Experimental flag** | `CUSTOM_ARGS="--stability.level=experimental"` in `/etc/default/alloy`. Required until Grafana marks these pieces stable. |
