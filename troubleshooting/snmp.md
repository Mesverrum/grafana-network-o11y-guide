# SNMP from the host

[← README](../README.md)

```
snmpget -v2c -c public -t 2 10.0.0.1:161 1.3.6.1.2.1.1.5.0
```

If this times out, Alloy will too (ACL, VRF, wrong community). Auth names in River must exist in `auths.yml`. v3: same USM user on the device and in the named block.
