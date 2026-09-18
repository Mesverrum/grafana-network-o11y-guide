# Fleet Management

[← README](../README.md)

**Idea:** manage Alloy’s non-secret config from a **central Grafana Cloud UI**, with version history, instead of ssh-editing `/etc/alloy/config.alloy` on every change. That is useful for one poller and for many. Each enrolled host pulls the pipeline. You still keep SNMP communities and the Cloud token **on the poller**.

**Skip Fleet on the first install.** Use the Compose files in this repo, get SNMP on **Health** / **Device Summary**, then come back. The `glc_` token from **OpenTelemetry → Configure** is almost always metrics/logs/traces write only — it cannot create a Fleet pipeline.

Today the UI is **Connections → Collector → Fleet Management**. (Grafana may fold this into an “Instrumentation Hub” later; the split is the same: names in Cloud, secrets on the host.)

## Enroll a poller

1. On the poller, Compose (or the host service) is already running the network image ([README](../README.md#quickstart)).
2. In Grafana Cloud, open **Connections → Collector → Fleet Management**.
3. **Add collector** (wording varies slightly). The UI prints a short config snippet that starts with `remotecfg`.
4. Put that snippet in `alloy/config.alloy` (Compose) or `/etc/alloy/config.alloy` (host service) and recreate / reload: `docker compose up -d --force-recreate` or `sudo systemctl reload alloy`.
5. The host should appear as online in Fleet.

That snippet only tells Alloy *where* to pull config. It is not where you put communities.

## What you put in the Fleet pipeline

Keep it small — things you would type in an NMS “add site” form:

- Group name (e.g. `hq`)
- CIDRs to scan — a list, e.g. `["10.0.0.0/24", "10.0.1.0/24"]`
- Auth **names** — a list, e.g. `["public_v2", "campus_v2"]`, not the community strings
- Whether to run hot / cold polls (`tiers = ["hot", "cold"]` in the sample)
- Trap / syslog / flow listen ports
- Per-IP **overrides** (generic sysObjectID / reskinned Linux) — [overrides.md](overrides.md)

Sample you can paste and then edit: [`alloy/fleet-pipeline.alloy.sample`](../alloy/fleet-pipeline.alloy.sample). It matches the local file: SNMP hot+cold, Alloy self-scrape (Health), traps `:11620`, syslog `:1514`, NetFlow `:2055`, sFlow `:6344`.

**Fleet is not a secret store.** If you are about to type `community:`, `password:`, `priv_password:`, or `glc_`, stop and put it on the poller instead ([secrets.md](secrets.md)).

Do not paste `snmp-network.yml` (the vendor OID library) into Fleet. It is large and already inside the image.

## What stays on the poller

- `alloy/auths.yml` (Compose) or `/etc/alloy/auths.yml` (host service) — or Vault / env, see [secrets.md](secrets.md)
- `GC_OTLP_*` in `.env` or `/etc/default/alloy`
- `--stability.level=experimental` (already in `compose.yaml`; host service sets `CUSTOM_ARGS`)
- The `remotecfg` snippet itself

**Export to Cloud:** the pipeline in Fleet cannot “call” blocks that exist only in the local file. Practical rule: put the “send to Grafana Cloud” export **in the Fleet sample** (it already does), *or* keep a local file that only does export and do not split one export across both. If you do both and they listen on the same trap/syslog port, one of them will fail to bind.

## Token permission

Creating or updating a Fleet pipeline needs an access policy with **fleet-management:write**. The token you copied from **Connections → OpenTelemetry** is often metrics/logs/traces write only.

In Grafana Cloud: **Administration** (or **Security**) → **Access policies** → create or edit a policy → enable Fleet Management write → new token. Put that token only in the enroll snippet / poller env — not in the pipeline text.

Many collectors: Fleet is how you **edit** them. It does not shard SNMP or fail over UDP. Split CIDRs per site, or `hashmod` a pool — [scalability.md](scalability.md). A dead poller is [availability.md](availability.md).
