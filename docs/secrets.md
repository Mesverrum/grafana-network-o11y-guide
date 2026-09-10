# Secrets (communities, v3, Cloud token)

[← README](../README.md)

**Grafana Fleet Management cannot store secrets.** That is a product limit, not a style choice. Anyone who can open the pipeline can read the text. Put credentials on the poller. Fleet only stores **names** like `public_v2`.

Official Alloy list of secret sources: [Secrets and credentials](https://grafana.com/docs/alloy/latest/access_permissions/).

## Start here: a file on the poller

Two ways to get `/etc/alloy/auths.yml`. Config and Fleet then list the **names** only (`public_v2`, `campus_v2`) — never the community string.

**Ask-and-write (good first time).** After you installed the network program ([install-alloy.md](install-alloy.md)), `snmp-discovery` is on the poller. It writes a `0600` auths file and a matching name list so you cannot typo `public_v2` in one place and `pubic_v2` in the other:

```
sudo snmp-discovery init \
  --out-auths /etc/alloy/auths.yml \
  --out-discovery /tmp/discovery.yml
```

With no `--auth-*` / `--group` flags it asks questions (community or v3, then CIDRs). Non-interactive:

```
sudo snmp-discovery init \
  --out-auths /etc/alloy/auths.yml \
  --out-discovery /tmp/discovery.yml \
  --auth-v2 public_v2=public \
  --group hq,cidrs=10.0.0.0/24,auths=public_v2
```

Copy the **names** (and CIDRs) into `/etc/alloy/config.alloy` or Fleet. Alloy does not read `discovery.yml` — you can delete it. Check names match:

```
snmp-discovery init --check --auths /etc/alloy/auths.yml --discovery /tmp/discovery.yml
```

**Or copy the example** and edit it yourself:

```
sudo cp alloy/auths.example.yml /etc/alloy/auths.yml
sudo chmod 600 /etc/alloy/auths.yml
sudo chown root:root /etc/alloy/auths.yml
```

One file, several named blocks:

`auths = ["public_v2", "campus_v2"]`

```yaml
auths:
  public_v2:
    version: 2
    community: public
  campus_v2:
    version: 2
    community: public
  dc_v3:
    version: 3
    security_level: authPriv
    username: netops
    password: "…"
    priv_password: "…"
    auth_protocol: SHA256
    priv_protocol: AES
```

The Cloud token (`GC_OTLP_KEY`) goes in `/etc/default/alloy` (or `/etc/sysconfig/alloy`), not in this file and not in Fleet. How to copy URL / instance ID / token: [grafana-cloud-otlp.md](grafana-cloud-otlp.md).

Compose users: same YAML, path `alloy/auths.yml` next to `compose.yaml` (`snmp-discovery init --out-auths alloy/auths.yml`). The Cloud token stays in `.env`.

## If your org already has a secret store

Alloy can read the **same YAML shape** from somewhere else. You do not have to use a file.

| If you already use | Alloy reads it with | Notes |
|--------------------|---------------------|--------|
| A file on disk | `local.file` (what the samples use) | `chmod 600` |
| An environment variable | `env("SNMP_AUTHS")` | Whole YAML in one variable |
| HashiCorp Vault | `remote.vault` | KV v2; many auth methods |
| Kubernetes | `remote.kubernetes.secret` | In-cluster only |
| A file in an S3 bucket | `remote.s3` | YAML object in the bucket |
| An HTTPS URL your team hosts | `remote.http` | Mark the body secret |

Vault example (only if you use Vault). Fleet still lists the names, not the passwords:

```alloy
remote.vault "snmp" {
  server = "https://vault.example.com"
  path   = "secret/data/network-o11y/snmp"
  auth.kubernetes { }
}

discovery.snmp "fabric" {
  auths = remote.vault.snmp.data["auths"]
  group {
    name  = "dc"
    cidrs = ["10.20.0.0/16", "10.21.0.0/16"]
    auths = ["dc_v3", "campus_v2"]
  }
}
```

Never put the community or v3 passphrases in the Fleet pipeline.
