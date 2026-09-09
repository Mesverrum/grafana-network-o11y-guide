# Find your Grafana Cloud OTLP URL, account, and token

[← README](../README.md)

Alloy needs three values to push data. Grafana does not email them. You copy them from the Cloud website after you can log in.

| This guide’s name | What it looks like | What Grafana calls it |
|-------------------|--------------------|------------------------|
| `GC_OTLP_URL` | `https://otlp-gateway-prod-….grafana.net/otlp` | **OTLP endpoint** |
| `GC_OTLP_ACCOUNT` | A number, e.g. `123456` | **Instance ID** (username for the gateway) |
| `GC_OTLP_KEY` | Starts with `glc_` | **Access policy token** (password for the gateway) |

You never open `GC_OTLP_URL` in a browser. It is a machine API. A GET in Chrome is supposed to look like an error (often 404).

Official background: [Send data to the Grafana Cloud OTLP endpoint](https://grafana.com/docs/grafana-cloud/send-data/otlp/send-data-otlp/).

## 0. You need a stack you can open

1. Go to [https://grafana.com](https://grafana.com) and sign in (Google / GitHub / email — whatever your company used).
2. You should land on an **organization Overview** with one or more **stacks** (a stack is one Grafana Cloud environment: dashboards + metrics + logs).
3. If you see nothing: you were not invited yet. Ask whoever owns Grafana Cloud to add you, or start a [Grafana Cloud](https://grafana.com/auth/sign-up/create-user) trial and create a stack.

Click **Launch** on the stack you will send network data to. Remember which one — URL, instance ID, and token must all be from **that** stack.

## 1. Easiest path — OpenTelemetry tile on the stack

Stay on the **grafana.com** stack page (the portal with product tiles), not inside dashboards yet.

1. Find the tile labeled **OpenTelemetry**.
2. Click **Configure** (not Launch).
3. The page shows:
   - **OTLP Endpoint** → copy the full `https://otlp-gateway-….grafana.net/otlp` into `GC_OTLP_URL`
   - **Instance ID** → the number → `GC_OTLP_ACCOUNT`
4. On the same page, **generate a token** (often **Generate now** / **Generate token**).
   - Name it something you will recognize, e.g. `network-poller`.
   - Copy the string that starts with `glc_` immediately. Grafana shows it **once**.
   - That is `GC_OTLP_KEY`.

If the generate button offers scopes, enable write for **metrics**, **logs**, and **traces**. You need all three for this guide (SNMP + flow metrics, trap/syslog logs).

Put the three values on the poller (`/etc/default/alloy`). Do not paste `GC_OTLP_KEY` into Fleet.

## 2. Alternate path — inside Grafana (Connections)

Use this if you already clicked **Launch** on the Grafana tile and are looking at dashboards.

1. Left menu → **Connections** (plug icon). If you only see **Add new connection**, click that.
2. Search for **OpenTelemetry**.
3. Open the **OpenTelemetry** connection (sometimes “OTLP”).
4. Follow the on-screen instructions. Copy:
   - endpoint URL → `GC_OTLP_URL`
   - instance / user id → `GC_OTLP_ACCOUNT`
   - token you create there → `GC_OTLP_KEY`

Menu names move slightly. If search finds nothing, go back to [section 1](#1-easiest-path--opentelemetry-tile-on-the-stack) on grafana.com.

## 3. If you have the URL but no token

Someone else may have created the stack. You still need your own token (or one your admin created for this poller).

1. In the Grafana UI: **Administration** (gear) → **Users and access** → **Cloud access policies**  
   or on grafana.com: **Security** → **Access policies**.
2. **Create access policy** (or open an existing one for this stack).
3. Scopes: **metrics:write**, **logs:write**, **traces:write**.
4. **Add token** → copy the `glc_…` value.

The instance ID is still on the OpenTelemetry tile, not on the access-policy page.

## Check you copied the right trio

| Check | OK | Wrong |
|-------|----|--------|
| URL | Starts with `https://otlp-gateway-` and ends with `/otlp` | Your dashboard URL (`https://something.grafana.net`) |
| Account | Digits only | Stack name / slug (`mycompany`) |
| Key | Starts with `glc_` | An old Grafana API key, or a password you use to log in |

All three must be from the **same** stack and **same** region (the region is in the gateway hostname, e.g. `prod-us-central-0`). Mixing a US URL with an EU token looks like 401.

Then continue the [README quickstart](../README.md#quickstart) at step 2.
