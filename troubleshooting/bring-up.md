# Bring-up

[← README](../README.md)

1. **Image** — `docker compose` fails with unknown component `discovery.snmp` → you are on stock `grafana/alloy`. Build [network-snmp](https://github.com/Mesverrum/alloy) and set `ALLOY_IMAGE`.
2. **`.env`** — placeholders or wrong region vs token → OTLP 401/404. Values must be one stack.
3. **`alloy/auths.yml`** — missing or names that do not match `group { auths = [...] }` → discovery walks nothing.
4. **CIDR reachability** — Alloy must share L2/L3 with the scan. Docker bridge cannot see a campus VLAN unless you `network_mode: host` or route it.
5. **Empty Grafana, local scrape up** — `up{job="alloy-snmp"}` locally vs Cloud token mismatch.
6. **Wrong PromQL** — `kentik_snmp_CPU` is the ktranslate name. Use `snmp_CPU`.
7. **Traps/syslog empty** — devices still pointed at an old collector IP/port; or remotecfg vs local both bound the same UDP port.

Alloy UI: http://127.0.0.1:12345 — check component health before Explore.
