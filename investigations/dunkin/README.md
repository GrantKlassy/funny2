# Dunkin' Ad Infrastructure Investigation

## What Happened

A Reddit promoted ad from `u/dunkin` appeared in our feed — a suspiciously well-crafted post where a "toddler typed gibberish" on the parent's phone, followed by a Dunkin' Zero Sugar product pitch. Clicking the ad navigated to `ulink.prod.ddmprod.dunkindonuts.com`, a deep subdomain that immediately revealed Dunkin's internal mobile platform naming.

We pulled the thread.

## What We Found

### The Ad Is Fake-Organic

The "toddler typing" is crafted by an adult copywriter. Keyboard analysis of the gibberish shows **77% of characters fall on the home row** (asdfghjkl) — the resting finger position for touch typists. A real toddler mashing keys produces roughly equal distribution across all three rows. The gibberish also contains strategically embedded words: `cat`, `dog`, `kid`, `mom`, `dad`, `dada` — all family-themed, all placed to make the post "feel" authentic.

This is a deliberate advertising technique: disguise promoted content as a relatable organic post to bypass ad fatigue on platforms like Reddit where users are trained to ignore anything labeled "Promoted."

### The URL Exposes an Entire Platform

`ulink.prod.ddmprod.dunkindonuts.com` is Dunkin's **custom Universal Links service** — part of a broader internal platform called **ddmprod** ("Dunkin' Donuts Mobile Production"). Through DNS, TLS certificate SANs, and Wayback Machine captures, we mapped the full platform:

| Service | Purpose |
|---------|---------|
| `mapi-dun` | Mobile API (primary cert CN — this is the app's backend) |
| `ulink` | Universal Links (deep link routing for ads/campaigns) |
| `ode` | Order Delivery Engine |
| `swi` | Unknown (returning 404 as of 2024 — possibly deprecated) |
| `k` | Web kickout/fallback (the interstitial page) |
| `dun-assets` | Static asset CDN (logos, images) |
| `cloud` | Cloud infrastructure (preprod only seen in Wayback) |

All services exist in both `prod` and `preprod` environments. The platform is hosted on **Akamai CDN** with **DigiCert ECC certificates** issued to **Dunkin' Brands, Inc., Canton, MA**.

### Three-Way User-Agent Routing

The `ulink` service is a Node.js/Express app behind Akamai that detects your device:

1. **Mobile + app installed** → iOS Universal Links / Android App Links open the Dunkin' app directly to `dunkin://orders/category/119`
2. **Mobile + no app** → Serves an interstitial page ("GET THE APP. ORDER AHEAD.") with a "Continue on App" button that routes through **Branch.io** (`dunkin.smart.link/f6iexb4x5`) to the App Store with deferred deep linking
3. **Desktop / Bot** → HTTP 302 redirect to `www.dunkindonuts.com/en/mobile-app`

### Reddit Targeting: Interest-Based

Wayback Machine captured historical URLs with full UTM parameters:
```
utm_source=reddit
utm_medium=paidsocial
utm_campaign=dunkinrun
utm_content=interests
```

The targeting parameter is literally called `interests` — Reddit served this ad based on interest/subreddit engagement patterns, not PII. Conversion tracking uses Reddit Click IDs (`rdt_cid` parameters) fed back through a Reddit Pixel for attribution.

### The Vendor Stack

| Vendor | Role | Evidence |
|--------|------|----------|
| **Branch.io** | Deep linking | `dunkin.smart.link` in landing page HTML |
| **OLO** | Online ordering | `order.dunkindonuts.com` → CNAME → `whitelabel.olo.com` |
| **CardFree** | Mobile payments/gift cards | AASA file: `com.cardfree.ddnationalprd` |
| **Akamai** | CDN | CNAME chain: `edgekey.net` → `akamaiedge.net` |
| **Proofpoint** | Email security | MX → `psmtp.com`, DMARC p=reject |
| **DigiCert** | TLS certs (mobile) | ECC SHA384 cert for ddmprod |
| **AWS** | Hosting, DNS | Route 53, ALB, ACM certs for root domain |

### Bonus: The www Cert Leaks 44 Subdomains

The TLS certificate on `www.dunkindonuts.com` lists 44 Subject Alternative Names, exposing their full SDLC topology: `dev2`, `qa`, `qa2`, `staging`, `staging3`, `uat` — plus SSO infrastructure, menu pricing APIs, QR menu services, franchisee portals, and cross-brand coverage for Baskin-Robbins.

## Methodology

All network probes ran inside containerized environments (`podman run --rm --dns 8.8.8.8 investigator`). No exploitation, no credential testing, no auth bypass. Standard OSINT: DNS enumeration, HTTP header inspection, TLS certificate analysis, Wayback Machine CDX queries, iTunes API lookups, Reddit public API, nmap port scanning.

## Files

- **[GRAPH.md](GRAPH.md)** — Structured knowledge graph (22 entities, 18 edges, 4 clusters)
- **`intake-2026-04-13/`** — Original evidence (screenshots, URL)
- **`artifacts/`** — Raw probe output (DNS, HTTP, certs, OSINT, gibberish analysis)
- **`scripts/`** — Reproducible probe scripts
