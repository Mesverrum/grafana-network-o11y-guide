# Availability

[← README](../README.md)

Grafana Cloud is already the redundant store (metrics, logs, dashboards). This page is about the **poller**: if that Linux host dies, SNMP gaps appear and UDP (traps, syslog, flow) is gone until something else is listening. How many devices one process can walk is [scalability.md](scalability.md).

There is no Alloy “cluster” that shares SNMP walks and UDP sockets for you. Treat this like a syslog / NetFlow collector: **one listen address the devices already know**, plus a plan for when that address moves.

## What actually fails

| If this dies | What you lose | What you do not lose |
|--------------|---------------|----------------------|
| The poller (disk, NIC, `alloy` process) | New SNMP samples; traps / syslog / flow that were aimed at that IP | Data already in Cloud. Dashboards still open. |
| Fleet / `remotecfg` (Cloud config pull) | New config edits | Running Alloy keeps the last pipeline it pulled. Secrets on disk still work. |
| Grafana Cloud ingest (token, outage) | New points in Cloud | Local Alloy may still scrape; you will not see it until push works again. |
| One site’s poller (when you split by site) | That site’s SNMP + UDP | Other sites. This is the cheapest “HA.” |

SNMP is pull: miss a 60s hot interval and you get a gap, then it resumes. Traps and flow are **push**: the packet is not stored on the device for Alloy. A 10-minute outage is a 10-minute hole in Loki / flow metrics.

## Default: one poller, systemd

The quickstart is a single host. Make that process boring:

- `sudo systemctl enable --now alloy` so it starts on boot.
- Disk for `/var/lib/alloy` (discovery state) and `/etc/alloy` (config + `auths.yml`).
- The poller sits on the **management** network. A jump box in a user VLAN is not a standby.

Compose on a laptop is for trying the image, not a failover pair.

## First real HA: one poller per site

Same as scale-out. `hq` and `dc` do not share a box. A failed poller darkens one `snmp_group`, not every device. Devices already send UDP to a **local** collector IP — you do not invent a global anycast on day one.

Fleet still helps: one pipeline *shape*, different CIDR lists (or different pipelines) per collector ([fleet.md](fleet.md)).

## Active-standby (same site)

Two Linux hosts, **one** address the devices use.

1. Install the network Alloy binary and the same `auths.yml` (or Vault) on both ([secrets.md](secrets.md), [install-alloy.md](install-alloy.md)).
2. Enroll both in Fleet, or keep `/etc/alloy/config.alloy` in sync. Same listen ports, same groups.
3. Put a **floating management IP** in front (VRRP / keepalived / your load-balancer’s UDP/IP). Devices’ trap / syslog / flow dest = that VIP. SNMP is initiated **from** whichever host owns the VIP (or from a shared SNAT), so ACLs must allow both real IPs if you do not SNAT.
4. Only the **master** should bind the UDP ports and run the walks. The backup has Alloy installed and config ready; it takes the VIP when the master fails.

Do **not** run Alloy on both boxes with the same CIDRs and both `systemctl start`’d “for redundancy.” That is two walkers and two processes fighting for `:1514` / `:2055` / `:11620`.

Standby cutover is **minutes**, not hitless: UDP in flight during the VRRP move is lost; SNMP resumes on the next interval.

## Why “just run two Alloy” is not HA

| Setup | What happens |
|-------|----------------|
| Two processes, same CIDRs, no shard | 2× SNMP on every device. Duplicate `snmp_*` in Cloud. |
| Two processes, same host, same UDP ports | One fails to bind. You already hit this if local config **and** Fleet both listen ([fleet.md](fleet.md)). |
| Two processes, two IPs, devices still aimed at IP-A | Killing A loses traps/flow. B never sees them. |
| Two processes, `hashmod` shards, one dies | That remainder goes dark. The other shard stays up. This is **scale**, not failover, unless you re-shard. |

Active-active SNMP is a **pool** ([scalability.md](scalability.md#same-cidr-several-pollers-snmp-shard)): each host walks a remainder. To survive a lost shard you need a human or automation to change `modulus` / `regex` (or a spare that was idle). There is no automatic “pick up remainder 2.”

## UDP: VIP, anycast, or dual export

Devices send traps / syslog / NetFlow to **one** (sometimes two) IPs.

| Pattern | Use when |
|---------|----------|
| **VIP / VRRP** (above) | Same site, active-standby. Usual campus choice. |
| **Anycast** (same collector IP on two pollers, routing steers) | You already run anycast for DNS/NTP and understand UDP and equal-cost paths. Easy to blackhole or split-brain if both announce. |
| **Two dests on the device** | The OS supports two trap hosts or two flow exporters. True dual ingest; Cloud gets two copies unless you filter by `snmp_group` / collector. Cost is device CPU + ingest. |
| **UDP load balancer** | Rarely worth it. No session for “stickiness”; you still need one logical collector IP. |

Sample ports in this guide: traps `11620`, syslog `1514`, NetFlow `2055`, sFlow `6344`. Changing them means changing **every device** and the Alloy listen config together.

## Config and secrets on a pair

- **Fleet** is the available *config* plane. If Cloud is unreachable, Alloy keeps the last pipeline. You can still `systemctl reload` a local file if you left a bootstrap `config.alloy` on disk.
- **Communities / v3 / `GC_OTLP_KEY`** are on the host. A standby without `auths.yml` will come up and discover nothing. Copy the file (mode `0600`) or use Vault / the same env on both ([secrets.md](secrets.md)).
- The OTLP token is **not** a Fleet token. Losing Cloud write is an ingest outage, not a collector crash.

## What to watch

**Health** (A1) and the local page http://127.0.0.1:12345 on the poller (or the VIP).

- `up{job="alloy-snmp",snmp_tier="hot"} == 0` — walks failing (device, path, or this poller).
- `discovery_snmp_devices` dropping — catalog shrinking (auth, CIDR, or the process restarted empty).
- Loki `{service_name="alloy-snmptrap"}` / `{service_name="alloy-syslog"}` going silent — VIP moved, device dest wrong, or port bind lost.
- `count(alloy_network_io_by_flow_bytes{integration="alloy-netflow"})` — exporters still hitting **this** listener.

Alert on “poller up and scrape up,” not only on Cloud. A healthy Grafana with a dead collector looks like a quiet network.

## Practical order

1. One poller, systemd, Health dashboard green.
2. Split **sites** before you invent a cluster.
3. Same-site VIP + cold standby if that site cannot be dark.
4. SNMP `hashmod` only when one site’s walks miss their interval ([scalability.md](scalability.md)).
5. Dual device export only if the platform already supports two collectors and you accept duplicate ingest.
