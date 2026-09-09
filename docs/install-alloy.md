# Install the network Alloy program

[← README](../README.md)

`apt install alloy` (or the RHEL package) installs Grafana’s **published** collector and the Linux service. That is enough for generic metrics and syslog. It is **not** enough for this guide.

This guide’s config uses three pieces that are not in that package yet:

- Scan a CIDR and pick SNMP modules (`discovery.snmp`)
- Receive SNMP traps
- Receive NetFlow / IPFIX / sFlow

Those exist on GitHub as [Mesverrum/alloy](https://github.com/Mesverrum/alloy), branch **`network-snmp`**. You compile that branch with Docker, then replace `/usr/bin/alloy` so `systemctl` runs the new program. You do **not** need to install the Go language.

Use any machine with Docker for the compile (poller or a laptop). Copy the files to the poller if you built elsewhere (`scp`).

## 1. Download the source

```
git clone --branch network-snmp --single-branch https://github.com/Mesverrum/alloy.git
cd alloy
```

Check the branch:

```
git branch --show-current
```

It must print `network-snmp`. If you cloned without `--branch`, the default is stock Alloy and the next build will not help.

## 2. Compile (Docker)

First run downloads several GB and often takes **15–40 minutes**. Leave it running.

```
docker build -f Dockerfile.network-src -t alloy-network:dev .
```

When it returns to a prompt with no error, you have a local Docker image named `alloy-network:dev`. That image is also what the optional laptop Compose file expects (`ALLOY_IMAGE=alloy-network:dev`).

## 3. Install the program on the poller

The service already points at `/usr/bin/alloy` and `/etc/alloy/`. Replace the program and add the SNMP vendor library. **Do not** overwrite `/etc/alloy/config.alloy` with the example from the image — that would wipe the file you are about to edit.

```
sudo cp -a /usr/bin/alloy /usr/bin/alloy.dist

docker create --name alloy-extract alloy-network:dev
sudo docker cp alloy-extract:/bin/alloy /usr/bin/alloy
sudo docker cp alloy-extract:/etc/alloy/snmp-network.yml /etc/alloy/snmp-network.yml
sudo docker cp alloy-extract:/etc/alloy/fingerprinters.yml /etc/alloy/fingerprinters.yml
docker rm alloy-extract
```

If the two `.yml` copies fail, list what the image actually contains:

```
docker run --rm --entrypoint ls alloy-network:dev /etc/alloy
```

Copy every `*.yml` you see **except** `config.alloy`.

Built on a laptop? `scp` `/usr/bin/alloy` and those two YAML files to the poller, then `sudo install -m 755 alloy /usr/bin/alloy`.

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

Then go back to the [README quickstart](../README.md#quickstart) for `auths.yml`, config, and Explore.

## Optional: Docker Compose on a laptop

After step 2, in **this** repo (the guide), not inside the `alloy` clone:

```
cd /path/to/grafana-network-o11y-guide
cp .env.sample .env
cp alloy/auths.example.yml alloy/auths.yml
cp alloy/config.alloy.sample alloy/config.alloy
```

Edit `.env` (Cloud URL / account / token) and the CIDR in `alloy/config.alloy`. Then:

```
docker compose up -d
```

Docker’s default bridge often cannot reach a management VLAN. On Linux, set `network_mode: host` in `compose.yaml`, or use a real poller.

## Files that matter

| Path | Who creates it |
|------|----------------|
| `/usr/bin/alloy` | You, from the Docker build |
| `/etc/alloy/snmp-network.yml` | Copied from the build (vendor OIDs) |
| `/etc/alloy/fingerprinters.yml` | Copied from the build (`sysObjectID` → modules) |
| `/etc/alloy/auths.yml` | **You** — communities / v3 |
| `/etc/alloy/config.alloy` | **You** — from the samples in this repo |
| `/etc/default/alloy` | Package + your `CUSTOM_ARGS` and `GC_OTLP_*` |

When Grafana ships these pieces in the official package, you can go back to `apt-get install alloy` and skip this page.
