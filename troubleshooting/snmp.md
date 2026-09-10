# Check SNMP from the poller

[← README](../README.md)

Alloy only does what this host can already do. Run these **on the poller** (or `network_mode: host`), not from your laptop unless the laptop is on the management network.

Install a client if needed: `sudo apt-get install snmp` (Debian / Ubuntu) or `sudo dnf install net-snmp-utils` (RHEL).

## SNMPv2c — sysName

Replace the IP and community:

```
snmpget -v2c -c public -t 2 10.0.0.1:161 1.3.6.1.2.1.1.5.0
```

`1.3.6.1.2.1.1.5.0` is `sysName`. A timeout or `Timeout: No Response` means Alloy will also get nothing: ACL, management VRF, SNMP disabled, or wrong community.

## SNMPv3

The **username**, auth/priv protocols, and passwords must match a named block in `/etc/alloy/auths.yml` and the device USM user.

```
snmpget -v3 -l authPriv -u netops -a SHA-256 -A 'auth-pass' -x AES -X 'priv-pass' \
  -t 2 10.0.0.1:161 1.3.6.1.2.1.1.5.0
```

## Config names

In `/etc/alloy/config.alloy` (or Fleet), every name in `auths = ["public_v2", "campus_v2"]` must be a key under `auths:` in `/etc/alloy/auths.yml`. A typo here looks like “discovery is broken” but is just a name mismatch.
