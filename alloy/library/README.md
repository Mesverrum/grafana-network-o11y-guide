# Local SNMP library overlay

Empty until you extract the files from the running image. Compose then bind-mounts them over the copies baked into `ghcr.io/mesverrum/alloy-network`.

```
bash scripts/extract-snmp-library.sh
cp compose.override.example.yaml compose.override.yaml
# edit fingerprinters.yml / snmp-network.yml
docker compose up -d --force-recreate
```

`fingerprinters.yml` is sysObjectID → module names. `snmp-network.yml` is the modules. They are one catalog — do not mix an extract from `v0.1.0` with a convert from a newer snmp-sd.

These two YAML files are gitignored. The Alloy binary does not need a rebuild.
