# Scalability

[← README](../README.md)

Start with **one Alloy on one Linux poller per management domain** (a site, a VRF, a DC fabric). That is the scale-out unit. Do not put every CIDR in the company on the first box and then try to “cluster” it.

Grafana Cloud stores and queries the data. This page is about the **collector**: how much SNMP you walk, how much UDP you ingest, and when to add another poller. High availability (what happens when that box dies) is a different problem: [availability.md](availability.md).

## Sizing (rule of thumb)

Same shape as the ktranslate planning table: **one CPU + 1 GiB per column**, sized for **peak** in a poll cycle (average 20% can hide a scrape that hits 100%). These are **field numbers**, not SLAs.

Lab (2026-09-09): one Alloy, `GOMAXPROCS=1`, image `srl-local/alloy:network-dev`. SNMP = 100 simulated **48-port** switches (IF-MIB hot + `if_mib_meta` cold, localhost, no timeout). Syslog = `otelcol.receiver.syslog` `protocol=none` + local OTLP HTTP. Peak SNMP was **0.12 core / ~100 MiB** for those 100 boxes (~4 800 interfaces).

| Workload | Starting budget | What “1 unit” covers |
|----------|-----------------|----------------------|
| SNMP polling | **1 CPU + 1 GiB RAM** | about **400** campus 48-port switches (**~20 000 interfaces**) |
| Syslog | **1 CPU + 1 GiB RAM** | about **2000 events/s** |
| SNMP traps | **1 CPU + 1 GiB RAM** | about **1000 events/s** |
| NetFlow / IPFIX / sFlow | **1 CPU + 1 GiB RAM** | about **1000 flow records/s** (metrics path, not Loki) |

Mental math:

- **Devices per core / GiB:** ~400 average 48-port switches. A core switch or wireless controller with thousands of ifIndex rows counts as **many** of those boxes — use **interfaces / core (~10 000)** when the estate is mixed.
- **EPS per core:** syslog is the cheap lane (lab held **6 400/s** with almost no loss and **12 800/s** at ~5% miss). Traps and flow decode more; **1000/s** matches the conservative ktranslate column until you measure your packet mix.

Worked examples:

- 1 200 access switches, SNMP only → about **3 CPU / 3 GiB** on the poller (or two site pollers).
- 4 000 flow records/s → about **4 CPU / 4 GiB** on the host that listens for NetFlow.
- Traps *and* syslog on the same Alloy are **two** 1000–2000/s columns if both are hot.

What eats the SNMP budget faster than “400 devices”:

- Large interface tables (core / DC / wireless controllers)
- Devices that never answer (walks sit on timeout)
- Hot interval shorter than 60s, or topology walks left on
- A second NMS walking the same community

Lab peak was ~800 devices/core because the simulator answers in-process with no loss. **Plan at 400.** Do not spend the same 1 CPU on 400 polled devices *and* 2000 syslog/s *and* 1000 flow/s — split listeners or add a core.

Leave **the host OS** outside this math. Grafana Cloud ingest/query is a different bill ([Cloud cost](#cloud-cost-is-usually-labels-not-hosts)).

Re-run the 1-CPU lab (simulator, not the Clos): `bash local/scripts/run-alloy-scale-bench.sh` in [network-o11y-demo](https://github.com/Mesverrum/network-o11y-demo).

## First knob: do not walk everything every minute

Hot / cold / topology already exist so you do not SNMP-walk the same OIDs at the same interval ([architecture.md](architecture.md)):

| If this is tight | Do this first |
|------------------|---------------|
| CPU on the poller or on the devices | Keep **hot** at 60s. Leave **cold** at 5m. Turn **topology** off unless you need LLDP / BGP-class walks. |
| Discovery taking longer than `refresh_interval` | Split the CIDR. A discovery sweep is capped around **1024 hosts per prefix** (IPv4 `/22`, IPv6 `/118`). Use two `/24`s, not one `/16`. |
| Devices complaining about SNMP load | You are walking the same box twice — two Alloy processes, or this poller plus the old NMS. Fix overlap before you add hardware. |
| Grafana Cloud bill / slow queries | Cardinality, not poller CPU. See [Cloud cost](#cloud-cost-is-usually-labels-not-hosts) below. |

Watch **Health** (A1): `discovery_snmp_scan_duration_seconds`, `up{job="alloy-snmp"}`, and scrape errors. If hot `up` flaps while `snmpget` from the poller is fine, the walk is missing its interval — split the group or add a poller.

## Scale-out that works: another site, another poller

Give each poller its **own** `discovery.snmp` groups (own CIDRs). Fleet can push the same *shape* of config to many hosts; the lists still have to be **this host’s prefixes** ([fleet.md](fleet.md)).

```
hq-poller      group hq       cidrs = ["10.1.0.0/24", …]
dc-poller      group dc       cidrs = ["10.2.0.0/24", …]
branch-poller  group branch1  cidrs = ["10.10.0.0/24"]
```

Devices in that VRF send traps / syslog / flow to **that** poller’s management IP. Dashboards filter `snmp_group`. One poller down darkens one site, not the estate — that is also your first availability win.

Do **not** enroll two pollers on the **same** CIDR with the stock sample. Both will discover the same IPs and both will walk them. Devices see 2× SNMP. Cloud sees duplicate series.

## Same CIDR, several pollers (SNMP shard)

Only when one site is too large for one process. Split the **target list**, not the UDP listeners.

Each poller can run `discovery.snmp` on the same CIDRs (a 5-minute sweep is cheap compared with a 60s walk). Before `prometheus.exporter.snmp`, keep only this host’s remainder. Same MD5 `hashmod` Prometheus uses:

```
// On poller 0 of 4. Change the regex to "1", "2", "3" on the others.
discovery.relabel "snmp_shard" {
  targets = discovery.snmp.fabric.targets

  rule {
    source_labels = ["__address__"]
    modulus       = 4
    target_label  = "__tmp_hash"
    action        = "hashmod"
  }

  rule {
    source_labels = ["__tmp_hash"]
    regex         = "0"
    action        = "keep"
  }
}
```

Point `prometheus.exporter.snmp` at `discovery.relabel.snmp_shard.output` (then the usual hot / cold keep rules). **The same modulus and the same `__address__` hash on every poller.** A leftover that two hosts keep is a double walk.

If you use the `snmp-discovery` CLI as a **single** catalog (`--listen :9780`) instead of in-process `discovery.snmp`, pollers scrape that HTTP SD and apply the same `hashmod`. One writer for the list; many walkers. Debug equivalent: `GET /sd?shard=0&shards=4`.

Shards are not failover. If poller `0` dies, remainder `0` goes dark until you change `modulus` / `regex` or bring the box back. Pair with [availability.md](availability.md).

## Traps, syslog, and flow do not shard the same way

Those are **UDP to one destination**. The device has one (sometimes two) collector IPs in its config. A second Alloy on the same port does not “share the load”; one binds, or you need a VIP / anycast ([availability.md](availability.md)).

| Signal | What grows | Budget (per core) | What to do |
|--------|------------|-------------------|------------|
| SNMP poll | Walks × interfaces × interval | ~400 × 48-port, or ~10k ifaces | More pollers **or** fewer OIDs / slower cold. Shard if one site is huge. |
| Syslog | Packet rate to **one** listen IP | ~2000 eps (lab >6k) | Bigger NIC / one poller per site. Do not run two listeners on the same IP:port. |
| Traps | Same | ~1000 eps | Same as syslog. |
| NetFlow / sFlow | Exporters × **records** | ~1000 records/s | One listener per site. **Metrics** (`rate(alloy_network_io_by_flow_bytes…)`). Do **not** turn on per-flow logs in Loki for a campus — that is not the scale path. |
| Discovery | Prefix size | Sweep cap ~`/22` | Split CIDRs. Do not scan RFC1918 from one box. |

If a platform can export flow or traps to **two** collectors, that is dual-write (two sites or active-active ingest), not a shard.

## Cloud cost is usually labels, not hosts

`device_name` + `ifIndex` + `snmp_group` is the intended grain. Do **not** stamp CMDB site, rack, owner, or a unique `instance` per scrape tier onto every series unless you have a reason. Cross-tier ratios must not join on Alloy’s per-component `instance` (`fabric_hot` vs `fabric_cold`).

Flow series grow with unique conversations. Sample or aggregate on the exporter if Cloud ingest is the bill, not the poller.

Recording rules (memory %, error %) belong in Grafana Cloud, not as extra SNMP walks.

## What is not a scale path

- **Compose on a laptop** — fine to try the image ([README](../README.md#optional-docker-compose)). Production still wants systemd on a host that can `snmpget` the devices.
- **Pasting `snmp-network.yml` into Fleet** — megabytes; already on the host from install.
- **A second NMS walking the same community** — looks like “Alloy is slow.”
- **Replicas of one Alloy with the same config and no `hashmod`** — 2× SNMP, duplicate metrics.

## When to add hardware

Add a poller when **Health** shows walks missing their interval, or when a management VRF cannot reach the first box. Prefer **another site** over sharding one CIDR. Shard only after hot/cold and CIDR splits are already in place.
