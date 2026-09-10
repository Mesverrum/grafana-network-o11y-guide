# Contributing

This repo is a **how-to for network engineers**. Keep pages copy-pasteable. Do not assume the reader is a Grafana SE or a software developer. Define Grafana-only words or link [docs/glossary.md](docs/glossary.md).

## What belongs here

- Quickstart, config samples, dashboard JSON, Explore queries, troubleshooting
- Re-export A0–A4 from the live Alloy folder with `python local/scripts/export-alloy-dashboards-guide.py` in [network-o11y-demo](https://github.com/Mesverrum/network-o11y-demo) (writes portable v2 JSON here; do not bake a lab stack UID)
- Install steps a reader can run without another repo ([docs/install-alloy.md](docs/install-alloy.md))
- Links to [snmp-sd](https://github.com/Mesverrum/snmp-sd), [grafana/alloy](https://github.com/grafana/alloy), and the [network-snmp branch](https://github.com/Mesverrum/alloy)

## What does not

- Alloy or snmp-sd source code
- A full lab (ContainerLab, Terraform, extra collectors) — that stays in [network-o11y-demo](https://github.com/Mesverrum/network-o11y-demo)
- Real `.env`, real `auths.yml`, or communities in Fleet samples

## README is the index

Detail lives in `docs/` and `troubleshooting/`. New capability → one line under **More detail** on the README.
