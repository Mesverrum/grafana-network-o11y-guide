# Fleet and Instrumentation Hub

[← README](../README.md)

The product story is **GUI-driven config, collector picks it up**. Today that GUI is Grafana Cloud **Connections → Collector → Fleet Management**. A future Instrumentation Hub should generate the same surface.

## What goes in Fleet

Operator config only — small, editable in a form:

- Discovery groups: name, CIDRs, auth **names** (`public_v2`, not the community)
- Which scrape tiers to run
- Enable traps / syslog / netflow and listen ports

Sample River: [`alloy/fleet-pipeline.alloy.sample`](../alloy/fleet-pipeline.alloy.sample).

The MIB library and fingerprinters stay in the **image**. Do not paste megabyte YAML into Fleet.

## What stays on the collector

- Secrets — [docs/secrets.md](secrets.md)
- OTLP bootstrap if you also receive locally (`remotecfg` cannot call components in the local ConfigMap)
- `--stability.level=experimental` until the network components are GA

## Why a lab might have remotecfg off

If you dual-run ktranslate and Alloy, Fleet must not bind `:1620` / `:1514` or ktranslate loses traps/syslog. That is a harness hack. Design partners should see **Alloy-only + remotecfg**, not parallel collectors.

## Token

Upserting a pipeline needs `fleet-management:write`. A metrics-only OTLP key is not enough.
