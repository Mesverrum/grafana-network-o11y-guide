#!/usr/bin/env python3
"""Import grafana/recording-rules.yaml as Grafana-managed recording rules.

Uses the Grafana convert/prometheus API (same path as
Alerting → More → Import to Grafana-managed rules → Prometheus YAML).

  export GRAFANA_URL=https://<stack>.grafana.net
  export GRAFANA_TOKEN=glsa_…    # Alerting: Write — not the OTLP GC_OTLP_KEY
  python3 scripts/import-recording-rules.py

Optional: --datasource-uid, --folder-uid, --dry-run.
"""
from __future__ import annotations

import argparse
import json
import os
import ssl
import sys
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_YAML = HERE.parent / "grafana" / "recording-rules.yaml"
DEFAULT_FOLDER_TITLE = "Network O11y"
DEFAULT_FOLDER_UID = "network-o11y"


def load_dotenv(path: Path) -> None:
    if not path.is_file():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def http(
    url: str,
    token: str,
    method: str,
    path: str,
    *,
    body: bytes | None = None,
    content_type: str = "application/json",
    extra_headers: dict[str, str] | None = None,
) -> tuple[int, object]:
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
        "Content-Type": content_type,
    }
    if extra_headers:
        headers.update(extra_headers)
    req = urllib.request.Request(
        url.rstrip("/") + path,
        data=body,
        method=method,
        headers=headers,
    )
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=120) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode(errors="replace")
        try:
            payload: object = json.loads(raw)
        except Exception:
            payload = {"raw": raw[:4000]}
        return exc.code, payload


def find_prom_uid(url: str, token: str, explicit: str) -> str:
    if explicit:
        return explicit
    status, data = http(url, token, "GET", "/api/datasources")
    if not (200 <= int(status) < 300) or not isinstance(data, list):
        raise SystemExit(f"list datasources -> {status}: {data}")
    prom = [d for d in data if d.get("type") == "prometheus"]
    for prefer in ("grafanacloud-prom", "prometheus"):
        for d in prom:
            if d.get("uid") == prefer or d.get("name") == prefer:
                return str(d["uid"])
    if not prom:
        raise SystemExit("No Prometheus data source on this stack.")
    return str(prom[0]["uid"])


def ensure_folder(url: str, token: str, folder_uid: str) -> str:
    status, data = http(url, token, "GET", f"/api/folders/{folder_uid}")
    if 200 <= int(status) < 300:
        return folder_uid
    body = json.dumps({"uid": folder_uid, "title": DEFAULT_FOLDER_TITLE}).encode()
    status, data = http(url, token, "POST", "/api/folders", body=body)
    if 200 <= int(status) < 300:
        return folder_uid
    if int(status) == 409:
        return folder_uid
    raise SystemExit(f"create folder {folder_uid} -> {status}: {data}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--yaml", type=Path, default=DEFAULT_YAML)
    ap.add_argument("--datasource-uid", default="")
    ap.add_argument("--folder-uid", default=DEFAULT_FOLDER_UID)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    load_dotenv(HERE.parent / ".env")
    url = os.environ.get("GRAFANA_URL", "").rstrip("/")
    token = os.environ.get("GRAFANA_TOKEN", "")
    if not url or not token:
        print(
            "Set GRAFANA_URL (https://<stack>.grafana.net) and GRAFANA_TOKEN\n"
            "(Grafana service account with Alerting: Write — not GC_OTLP_KEY).",
            file=sys.stderr,
        )
        return 2
    if "otlp-gateway" in url:
        print(
            "GRAFANA_URL must be the dashboard URL, not GC_OTLP_URL.",
            file=sys.stderr,
        )
        return 2
    if not args.yaml.is_file():
        raise SystemExit(f"missing {args.yaml}")

    ds = find_prom_uid(url, token, args.datasource_uid)
    if args.dry_run:
        print(f"dry-run: would import {args.yaml} → {url}")
        print(f"  datasource_uid={ds} folder_uid={args.folder_uid}")
        return 0

    folder = ensure_folder(url, token, args.folder_uid)
    yaml_bytes = args.yaml.read_bytes()
    status, data = http(
        url,
        token,
        "POST",
        "/api/convert/prometheus/config/v1/rules",
        body=yaml_bytes,
        content_type="application/yaml",
        extra_headers={
            "X-Grafana-Alerting-Datasource-UID": ds,
            "X-Grafana-Alerting-Target-Datasource-UID": ds,
            "X-Grafana-Alerting-Folder-UID": folder,
            "X-Disable-Provenance": "true",
        },
    )
    if not (200 <= int(status) < 300):
        print(
            f"import failed ({status}): {data}\n"
            "Use the UI path in docs/recording-rules.md, or check the token "
            "has Alerting: Write on this stack.",
            file=sys.stderr,
        )
        return 1
    print(f"Imported {args.yaml.name} into {url} folder={folder} datasource={ds}")
    print("Wait ~1–2m, then Explore: count(if:snmp_ifHCInOctets:rate5m)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
