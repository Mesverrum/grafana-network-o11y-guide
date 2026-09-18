# Install the network Alloy program

[← README](../README.md)

The first-time path is **Docker Compose** on a Linux poller — [README quickstart](../README.md#quickstart). This page is the image itself, compile, and the optional host systemd service.

`apt install alloy` installs Grafana’s **published** collector. That package cannot run this guide’s SNMP discovery / traps / NetFlow. Do not start there unless you are following [run as a host service](#optional-run-as-a-host-service).

The extra pieces ship in a **public** image: [`ghcr.io/mesverrum/alloy-network`](https://github.com/Mesverrum/grafana-network-o11y-guide/pkgs/container/alloy-network) (personal GHCR, not `grafana/alloy`). Tags match [guide releases](https://github.com/Mesverrum/grafana-network-o11y-guide/releases). Fingerprinters and the vendor OID library default to **whatever that tag baked in**. Overlay local copies without compiling — [below](#optional-overlay-fingerprinters--modules).

| Path | When to use |
|------|-------------|
| [README Compose quickstart](../README.md#quickstart) | Default. Pull + run. No compile. |
| [Compile from source](#optional-compile-from-source) | You want to rebuild, or you do not trust a prebuilt binary. |
| [Host systemd service](#optional-run-as-a-host-service) | You already run Alloy with `systemctl` and want that layout. |

Source branch: [Mesverrum/alloy](https://github.com/Mesverrum/alloy) **`network-snmp`**.

## What Compose uses from the image

`compose.yaml` pulls `ALLOY_IMAGE` (default `ghcr.io/mesverrum/alloy-network:v0.1.0`), sets `--stability.level=experimental`, and uses `network_mode: host` so SNMP and UDP listeners share the poller’s interfaces.

You mount two files by default; the SNMP library stays inside the image until you [overlay it](#optional-overlay-fingerprinters--modules):

| Host path | Inside the container |
|-----------|----------------------|
| `alloy/config.alloy` | `/etc/alloy/config.alloy` |
| `alloy/auths.yml` | `/etc/alloy/auths.yml` |
| Docker volume `alloy-data` | `/var/lib/alloy/data` (discovery state) |
| `.env` | `GC_OTLP_*` |

Copy `config.alloy.sample` **before** `docker compose up`. If that path is missing, Docker creates a *directory* named `config.alloy` and Alloy will not start.

## Optional: overlay fingerprinters / modules

Keep the pulled image. Copy the baked catalog out, edit it, bind-mount it back. `discovery.snmp` already reads `/etc/alloy/fingerprinters.yml` and `/etc/alloy/snmp-network.yml` — you do not change River.

```
bash scripts/extract-snmp-library.sh
cp compose.override.example.yaml compose.override.yaml
# edit alloy/library/fingerprinters.yml
# and alloy/library/snmp-network.yml if you add or rename modules
docker compose up -d --force-recreate
```

Rules:

- **Same convert.** Fingerprinter `module=` names must exist in `snmp-network.yml`. Mixing a new map with the image catalog drops those modules (walk looks empty).
- **Fingerprinters only** is enough when you remap sysObjectIDs onto modules that are already in the image.
- **Both files** when you add a vendor module or a new `module=` name.
- `compose.override.yaml` is gitignored. Remove it (or the volume lines) to go back to the image library.
- Host service: `docker cp` the same two files onto `/etc/alloy/` instead of Compose override.

This is how early testers pick up a profile tweak without compiling Alloy. A new matcher *type* in snmp-sd still needs a new image.

## Optional: compile from source

Skip this if you pulled the public image. First compile downloads several GB and often takes **15–40 minutes**. Then set `ALLOY_IMAGE=alloy-network:dev` in `.env` and use the same Compose quickstart.

**From this repo** (clones `network-snmp` if you do not already have it next door):

```
git clone https://github.com/Mesverrum/grafana-network-o11y-guide.git
cd grafana-network-o11y-guide
export ALLOY_IMAGE=alloy-network:dev
bash scripts/build-network-image.sh
```

**From the Alloy fork** (same result, longer Docker context):

```
git clone --branch network-snmp --single-branch https://github.com/Mesverrum/alloy.git
cd alloy
docker build -f Dockerfile.network-src -t alloy-network:dev .
export ALLOY_IMAGE=alloy-network:dev
```

## Optional: run as a host service

Only if you want `systemctl start alloy` instead of Compose. You still need Docker once, to copy files out of the image.

### 1. Official Alloy service (file layout)

Debian / Ubuntu — skip this if `systemctl status alloy` already works:

```
sudo mkdir -p /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/grafana.asc https://apt.grafana.com/gpg-full.key
sudo chmod 644 /etc/apt/keyrings/grafana.asc
echo "deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update && sudo apt-get install alloy
```

Other distros: [Install Alloy on Linux](https://grafana.com/docs/alloy/latest/set-up/install/linux/).

### 2. Pull and copy

```
export ALLOY_IMAGE=ghcr.io/mesverrum/alloy-network:v0.1.0
docker pull "$ALLOY_IMAGE"

sudo cp -a /usr/bin/alloy /usr/bin/alloy.dist
docker create --name alloy-extract "$ALLOY_IMAGE"
sudo docker cp alloy-extract:/bin/alloy /usr/bin/alloy
sudo docker cp alloy-extract:/usr/bin/snmp-discovery /usr/bin/snmp-discovery
sudo docker cp alloy-extract:/etc/alloy/snmp-network.yml /etc/alloy/snmp-network.yml
sudo docker cp alloy-extract:/etc/alloy/fingerprinters.yml /etc/alloy/fingerprinters.yml
docker rm alloy-extract
```

**Do not** overwrite `/etc/alloy/config.alloy` with the example from the image. Copy this repo’s [`alloy/config.alloy.sample`](../alloy/config.alloy.sample) there after you edit CIDRs.

If the two `.yml` copies fail: `docker run --rm --entrypoint ls "$ALLOY_IMAGE" /etc/alloy` and copy every `*.yml` except `config.alloy`.

### 3. Experimental flag and Cloud env

Debian / Ubuntu: `/etc/default/alloy`. RHEL: `/etc/sysconfig/alloy`.

```
CUSTOM_ARGS="--stability.level=experimental"
GC_OTLP_URL=https://otlp-gateway-prod-<region>.grafana.net/otlp
GC_OTLP_ACCOUNT=123456
GC_OTLP_KEY=glc_…
```

Without the stability line, the service starts but ignores discovery / traps / flow.

Secrets: `sudo cp alloy/auths.example.yml /etc/alloy/auths.yml` and `chmod 600`. Then `sudo cp alloy/config.alloy.sample /etc/alloy/config.alloy` and edit CIDRs.

### 4. Prove it

```
alloy --version
sudo systemctl restart alloy
journalctl -u alloy -n 50 --no-pager
```

`unknown component "discovery.snmp"` means Linux is still running the old `/usr/bin/alloy`. Compare `ls -l /usr/bin/alloy /usr/bin/alloy.dist` and redo step 2.

Local UI: http://127.0.0.1:12345. Then import dashboards from the [README](../README.md#quickstart) step 6.

When Grafana ships these pieces in the official package, you can go back to `apt-get install alloy` and skip the image.
