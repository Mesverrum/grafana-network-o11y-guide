# Fleet Management

[← README](../README.md)

**Idea:** edit CIDRs and listen ports in Grafana Cloud; each poller picks the change up. You still keep SNMP communities and the Cloud token **on the poller**.

Today the UI is **Connections → Collector → Fleet Management**. (Grafana may fold this into an “Instrumentation Hub” later; the split is the same: names in Cloud, secrets on the host.)

## Enroll a poller

1. On the poller, Alloy is installed and the network binary is in place ([install-alloy.md](install-alloy.md)).
2. In Grafana Cloud, open **Connections → Collector → Fleet Management**.
3. **Add collector** (wording varies slightly). The UI prints a short config snippet that starts with `remotecfg`.
4. Put that snippet in `/etc/alloy/config.alloy` and reload: `sudo systemctl reload alloy`.
5. The host should appear as online in Fleet.

That snippet only tells Alloy *where* to pull config. It is not where you put communities.

## What you put in the Fleet pipeline

Keep it small — things you would type in an NMS “add site” form:

- Group name (e.g. `hq`)
- CIDRs to scan
- Auth **names** (`public_v2`) — not the community string
- Whether to run hot / cold / topology polls
- Trap / syslog / flow listen ports

Sample you can paste and then edit: [`alloy/fleet-pipeline.alloy.sample`](../alloy/fleet-pipeline.alloy.sample).

**Fleet is not a secret store.** If you are about to type `community:`, `password:`, `priv_password:`, or `glc_`, stop and put it on the poller instead ([secrets.md](secrets.md)).

Do not paste `/etc/alloy/snmp-network.yml` (the vendor OID library) into Fleet. It is large and already on the host from the install.

## What stays on the poller

- `/etc/alloy/auths.yml` (or Vault / env — see [secrets.md](secrets.md))
- `GC_OTLP_*` in `/etc/default/alloy`
- `CUSTOM_ARGS="--stability.level=experimental"`
- The `remotecfg` snippet itself

**Export to Cloud:** the pipeline in Fleet cannot “call” blocks that exist only in the local file. Practical rule: put the “send to Grafana Cloud” export **in the Fleet sample** (it already does), *or* keep a local file that only does export and do not split one export across both. If you do both and they listen on the same trap/syslog port, one of them will fail to bind.

## Token permission

Creating or updating a Fleet pipeline needs an access policy with **fleet-management:write**. The token you copied from **Connections → OpenTelemetry** is often metrics/logs/traces write only.

In Grafana Cloud: **Administration** (or **Security**) → **Access policies** → create or edit a policy → enable Fleet Management write → new token. Put that token only in the enroll snippet / poller env — not in the pipeline text.
