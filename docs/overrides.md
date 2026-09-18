# Pin a device the fingerprinter cannot name

[← README](../README.md)

Discovery matches `sysObjectID` (and a couple of probe OIDs) to SNMP modules. Many appliances are a **reskinned Linux box**: sysObjectID is generic, `sysDescr` is unhelpful, and they land on `device_base` + `if_mib` only.

In ktranslate you pinned that IP to a profile in the device list. Here the pin is a **`discovery.snmp` override**, keyed by **management IP**, not by sysObjectID.

The box still has to be **found** (its IP is in a group `cidrs` list, or add `"10.20.0.15/32"`). An override does not create a target that was never scanned.

## One or two boxes — inline

In `alloy/config.alloy` (or the Fleet pipeline), inside `discovery.snmp "fabric"`:

```alloy
  override {
    address     = "10.20.0.15"
    name        = "edge-waf-01"                 // optional; becomes device_name
    auth        = "public_v2"                   // optional; name from auths.yml
    module_hot  = "if_mib,my_appliance"
    module_cold = "if_mib_meta,ip_addr,my_appliance_ext"
  }

  override {
    address = "10.20.0.16"
    ignore  = true                              // do not poll (jump box, duplicate)
  }
```

`module_hot` / `module_cold` are comma-separated **module names**. Those names must already exist in `snmp-network.yml`. Prefer the tier fields over legacy `module` (a single full chain).

After you edit: `docker compose up -d --force-recreate`.

## Many boxes — a YAML file

`alloy/overrides.example.yml` → `alloy/overrides.yml` (gitignored). Point discovery at it:

```alloy
discovery.snmp "fabric" {
  overrides_path = "/etc/alloy/overrides.yml"
  // groups …
}
```

Compose does **not** mount that file by default (a missing path becomes a directory). Add a volume in `compose.override.yaml`:

```yaml
services:
  alloy:
    volumes:
      - ./alloy/overrides.yml:/etc/alloy/overrides.yml:ro
```

Host service: put the file at `/etc/alloy/overrides.yml`.

Inline `override` blocks and `overrides_path` can be used together; both apply.

## New appliance profile

If no existing module walks the right OIDs:

1. Add the module to a [library overlay](install-alloy.md#optional-overlay-fingerprinters--modules) (`snmp-network.yml`).
2. Pin the IP to that module name as above.

Do not invent a `module=` name that is not in the catalog — the walk looks empty. A new sysObjectID row in `fingerprinters.yml` is the other path, when the OID *is* unique.

## Check

Explore:

```promql
snmp_CPU{device_name="edge-waf-01"}
```

Still generic Linux metrics only → the pin did not apply (wrong IP, not in CIDR, or module name missing from the catalog).
