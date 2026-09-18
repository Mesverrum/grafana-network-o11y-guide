# Secrets (communities, v3, Cloud token)

[← README](../README.md)

**Grafana Fleet Management cannot store secrets.** That is a product limit, not a style choice. Anyone who can open the pipeline can read the text. Put credentials on the poller. Fleet only stores **names** like `public_v2`. The OpenTelemetry `glc_` token stays in `.env` (Compose) or `/etc/default/alloy` (host service) — never in Fleet and never in this git repo.

Official Alloy list of secret sources: [Secrets and credentials](https://grafana.com/docs/alloy/latest/access_permissions/).

## Start here: a file on the poller

Compose (default) uses `alloy/auths.yml` next to `compose.yaml`. A host service uses `/etc/alloy/auths.yml`. Config and Fleet then list the **names** only (`public_v2`, `campus_v2`) — never the community string.

**Copy the example** (usual first time):

```
cp alloy/auths.example.yml alloy/auths.yml
chmod 600 alloy/auths.yml
```

Host service: `sudo cp alloy/auths.example.yml /etc/alloy/auths.yml && sudo chmod 600 /etc/alloy/auths.yml`.

**Or ask-and-write** with `snmp-discovery` from the image (optional):

```
docker run --rm -it --entrypoint snmp-discovery \
  -v "$PWD/alloy:/out" \
  ghcr.io/mesverrum/alloy-network:v0.1.0 \
  init --out-auths /out/auths.yml --out-discovery /tmp/discovery.yml
```

With no `--auth-*` / `--group` flags it asks questions (community or v3, then CIDRs). Alloy does not read `discovery.yml` — you can delete it. Copy the **names** (and CIDRs) into `alloy/config.alloy` or Fleet.

Fleet can read this same file (`local.file` in the sample). You do not have to stuff the YAML into `SNMP_AUTHS` for a first install.

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

The Cloud token (`GC_OTLP_KEY`) goes in `.env` (Compose) or `/etc/default/alloy` (host service), not in this file and not in Fleet. How to copy URL / instance ID / token: [grafana-cloud-otlp.md](grafana-cloud-otlp.md).

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
