# Secrets

[← README](../README.md)

Fleet has **no** secret store. That is intentional. The GUI stores auth **names**. Alloy on the collector resolves the blob.

Official Alloy guidance: [Access and permissions — Secrets and credentials](https://grafana.com/docs/alloy/latest/access_permissions/).

## Six documented sources

| # | Source | Component | Notes |
|---|--------|-----------|--------|
| 1 | Environment | `sys.env()` / `env("SNMP_AUTHS")` | Same YAML as `auths.example.yml` in one variable |
| 2 | File | `local.file` + `is_secret = true` / `auths_file` | What the Compose quickstart uses |
| 3 | HashiCorp Vault | [`remote.vault`](https://grafana.com/docs/alloy/latest/reference/components/remote/remote.vault/) | GA. KV v2. Auth: token, AppRole, Kubernetes, AWS, Azure, GCP, LDAP |
| 4 | Kubernetes | [`remote.kubernetes.secret`](https://grafana.com/docs/alloy/latest/reference/components/remote/remote.kubernetes.secret/) | In-cluster Secret |
| 5 | S3 object | [`remote.s3`](https://grafana.com/docs/alloy/latest/reference/components/remote/remote.s3/) | `is_secret = true` — a file in a bucket, not Secrets Manager |
| 6 | HTTP | [`remote.http`](https://grafana.com/docs/alloy/latest/reference/components/remote/remote.http/) | Poll a URL; mark the body secret |

There is **no** native `remote.aws.secretsmanager` ([alloy#689](https://github.com/grafana/alloy/issues/689)). AWS shops: External Secrets → Kubernetes Secret, dump into env/file at start, put the YAML in S3, or put Vault in front (`remote.vault` + `auth.aws`).

## Shape

One YAML document, many named blocks. Fleet lists the names:

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
