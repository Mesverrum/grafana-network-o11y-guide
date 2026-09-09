# Secrets (communities, v3, Cloud token)

[← README](../README.md)

**Grafana Fleet Management cannot store secrets.** That is a product limit, not a style choice. Anyone who can open the pipeline can read the text. Put credentials on the poller. Fleet only stores **names** like `public_v2`.

Official Alloy list of secret sources: [Secrets and credentials](https://grafana.com/docs/alloy/latest/access_permissions/).

## Start here: a file on the poller

```
sudo cp alloy/auths.example.yml /etc/alloy/auths.yml
sudo chmod 600 /etc/alloy/auths.yml
sudo chown root:root /etc/alloy/auths.yml
```

One file, several named blocks. Edit `community` / v3 fields to match the devices. Config and Fleet say `auths = ["public_v2"]` — they never contain the string `public`.

```yaml
auths:
  public_v2:
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

## If your org already has a secret store

Alloy can read the **same YAML shape** from somewhere else. You do not have to use a file.

| If you already use | Alloy reads it with | Notes |
|--------------------|---------------------|--------|
| A file on disk | `local.file` (what the samples use) | `chmod 600` |
| An environment variable | `env("SNMP_AUTHS")` | Whole YAML in one variable |
| HashiCorp Vault | `remote.vault` | KV v2; many auth methods |
| Kubernetes | `remote.kubernetes.secret` | In-cluster only |
| A file in an S3 bucket | `remote.s3` | A YAML object, **not** AWS Secrets Manager |
| An HTTPS URL your team hosts | `remote.http` | Mark the body secret |

There is **no** built-in AWS Secrets Manager hook yet ([alloy#689](https://github.com/grafana/alloy/issues/689)). Typical AWS workarounds: put the YAML in S3, inject it at boot into a file/env, or put Vault in front.

Vault example (only if you use Vault). Fleet still lists `dc_v3`, not the password:

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
    cidrs = ["10.20.0.0/16"]
    auths = ["dc_v3"]
  }
}
```

Never put the community or v3 passphrases in the Fleet pipeline.
