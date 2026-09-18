# Install the network Alloy program

[← README](../README.md)

`apt install alloy` (or the RHEL package) installs Grafana’s **published** collector and the Linux service. That is enough for generic metrics and syslog. It is **not** enough for this guide.

This guide’s config uses three pieces that are not in that package yet:

- Scan a CIDR and pick SNMP modules (`discovery.snmp`)
- Receive SNMP traps
- Receive NetFlow / IPFIX / sFlow

Those ship as a **prebuilt image**: [`ghcr.io/mesverrum/alloy-network`](https://github.com/Mesverrum/grafana-network-o11y-guide/pkgs/container/alloy-network). You pull it, copy three files onto the poller, and `systemctl` keeps working. You do **not** need Go.

Source (if you want to read or rebuild it): [Mesverrum/alloy](https://github.com/Mesverrum/alloy) branch **`network-snmp`**.

## 1. Official Alloy service (file layout)

Debian / Ubuntu — skip this if `systemctl status alloy` already works:

```
sudo mkdir -p /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/grafana.asc https://apt.grafana.com/gpg-full.key
sudo chmod 644 /etc/apt/keyrings/grafana.asc
echo "deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update && sudo apt-get install alloy
```

Other distros: [Install Alloy on Linux](https://grafana.com/docs/alloy/latest/set-up/install/linux/).

## 2. Pull the network image (no compile)

On any machine with Docker (the poller or a laptop):

```
export ALLOY_IMAGE=ghcr.io/mesverrum/alloy-network:v0.1.0
docker pull "$ALLOY_IMAGE"
```

If the pull asks you to log in, the package is still private — use the [compile fallback](#fallback-compile-from-source) or wait for the public package. Image tags match [guide releases](https://github.com/Mesverrum/grafana-network-o11y-guide/releases).

Compose users: set `ALLOY_IMAGE` in `.env` to that same tag and skip the copy steps below (`docker compose up -d`).

## 3. Install the program on the poller

The service already points at `/usr/bin/alloy` and `/etc/alloy/`. Replace the program and add the SNMP vendor library. **Do not** overwrite `/etc/alloy/config.alloy` with the example from the image — that would wipe the file you are about to edit.

```
sudo cp -a /usr/bin/alloy /usr/bin/alloy.dist

docker create --name alloy-extract "$ALLOY_IMAGE"
sudo docker cp alloy-extract:/bin/alloy /usr/bin/alloy
sudo docker cp alloy-extract:/usr/bin/snmp-discovery /usr/bin/snmp-discovery
sudo docker cp alloy-extract:/etc/alloy/snmp-network.yml /etc/alloy/snmp-network.yml
sudo docker cp alloy-extract:/etc/alloy/fingerprinters.yml /etc/alloy/fingerprinters.yml
docker rm alloy-extract
```

If the two `.yml` copies fail, list what the image actually contains:

```
docker run --rm --entrypoint ls "$ALLOY_IMAGE" /etc/alloy
```

Copy every `*.yml` you see **except** `config.alloy`.

Built or pulled on a laptop? `scp` `alloy`, `snmp-discovery`, and those two YAML files to the poller, then `sudo install -m 755 alloy /usr/bin/alloy` and the same for `snmp-discovery`.

## 4. Allow unfinished (but needed) components

Debian / Ubuntu: edit `/etc/default/alloy`. RHEL family: `/etc/sysconfig/alloy`. Add:

```
CUSTOM_ARGS="--stability.level=experimental"
```

Leave `CONFIG_FILE="/etc/alloy/config.alloy"` as the package set it.

Grafana hides unfinished features behind that flag. Without it, the service starts but ignores discovery / traps / flow.

## 5. Prove the new program is what is running

```
alloy --version
sudo systemctl restart alloy
journalctl -u alloy -n 50 --no-pager
```

If the log says `unknown component "discovery.snmp"`, Linux is still running the old `/usr/bin/alloy`. Compare dates:

```
ls -l /usr/bin/alloy /usr/bin/alloy.dist
```

Redo step 3.

On the poller, open http://127.0.0.1:12345 — Alloy’s **local** status page (component graph). That is not Grafana Cloud.

Then go back to the [README quickstart](../README.md#quickstart) for `auths.yml`, config, and dashboard import.

## Fallback: compile from source

Only if you cannot pull the image. First run downloads several GB and often takes **15–40 minutes**.

```
git clone --branch network-snmp --single-branch https://github.com/Mesverrum/alloy.git
cd alloy
docker build -f Dockerfile.network-src -t alloy-network:dev .
export ALLOY_IMAGE=alloy-network:dev
```

Then continue from [step 3](#3-install-the-program-on-the-poller).

## Optional: Docker Compose

Same image, as a container instead of systemd. Docker’s default bridge often cannot reach a management VLAN. On Linux, set `network_mode: host` in `compose.yaml`, or run Compose on a host that already sits on that network.

```
cd /path/to/grafana-network-o11y-guide
cp .env.sample .env
cp alloy/config.alloy.sample alloy/config.alloy
```

Set `ALLOY_IMAGE=ghcr.io/mesverrum/alloy-network:v0.1.0` in `.env`. Write communities / v3 into `alloy/auths.yml` (`snmp-discovery init --out-auths alloy/auths.yml`, or copy `alloy/auths.example.yml`). Edit the `cidrs` / `auths` lists in `alloy/config.alloy`. Then:

```
docker compose up -d
```

## Files that matter

| Path | Who creates it |
|------|----------------|
| `/usr/bin/alloy` | You, copied from the image |
| `/usr/bin/snmp-discovery` | Same image — `snmp-discovery init` writes the first `auths.yml` ([secrets.md](secrets.md)) |
| `/etc/alloy/snmp-network.yml` | Copied from the image (vendor OIDs) |
| `/etc/alloy/fingerprinters.yml` | Copied from the image (`sysObjectID` → modules) |
| `/etc/alloy/auths.yml` | **You** — communities / v3 |
| `/etc/alloy/config.alloy` | **You** — from the samples in this repo |
| `/etc/default/alloy` | Package + your `CUSTOM_ARGS` and `GC_OTLP_*` |

When Grafana ships these pieces in the official package, you can go back to `apt-get install alloy` and skip this page.
