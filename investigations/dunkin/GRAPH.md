# Dunkin' Ad Infrastructure Investigation

> Started: 2026-04-13
> Status: Active — probing complete, graph populated

## Trigger

Highly targeted Reddit promoted ad from `u/dunkin` using fake "toddler keyboard smashing" creative. Clicking the ad navigated to `ulink.prod.ddmprod.dunkindonuts.com`, a custom Universal Links service that routes mobile users to the Dunkin' app via Branch.io and desktop users to `www.dunkindonuts.com`. The deep subdomain naming exposed Dunkin's entire mobile backend platform.

## Entities

| ID | Type | Name | Notes |
|----|------|------|-------|
| E1 | domain | `dunkindonuts.com` | Root domain, registered 1995-07-13. Pre-2018 rebrand naming retained. AWS Route 53 NS, CSC Corporate Domains registrar. |
| E2 | service | `ulink.prod.ddmprod.dunkindonuts.com` | Universal Links router. Node.js/Express behind Akamai CDN. UA-based routing: mobile→200 interstitial, desktop/bot→302 to www. |
| E3 | service | `k.prod.ddmprod.dunkindonuts.com` | Does not resolve externally via DNS. Accessed only behind Akamai edge. Serves app interstitial (seen in dunkin3.jpg browser bar). |
| E4 | platform | `ddmprod` | "Dunkin' Donuts Mobile Production" — internal mobile app platform. Contains: mapi-dun (Mobile API), ulink (Universal Links), ode (Order Delivery Engine), swi (unknown), k (web kickout), dun-assets (static CDN), cloud (infra). Environments: prod, preprod. |
| E5 | reddit-account | `u/dunkin` | Corporate advertiser. Created 2018-10-18 (Dunkin' rebrand era). Verified, moderator. 62 link / 67 comment karma. Promoted posts not visible via public API. |
| E6 | ad-network | Reddit Ads | Targeting: interest-based (`utm_content=interests`). Campaign: `dunkinrun`. Medium: `paidsocial`. Conversion tracking via Reddit Pixel (`rdt_cid`). |
| E7 | deep-link | `dunkin://orders/category/119` | App URI scheme deep link. Category 119 = current campaign product. Previous campaigns used categories 28, 53, 70. |
| E8 | parent-company | Inspire Brands | Acquired Dunkin' Brands 2020. Parent of Dunkin', Baskin-Robbins, Arby's, Buffalo Wild Wings, Sonic. |
| E9 | vendor | Branch.io | Deep linking vendor. Smart links at `dunkin.smart.link`. Link ID: `f6iexb4x5`. Provides deferred deep linking (App Store → app open with preserved context). |
| E10 | vendor | OLO | Online ordering platform. `order.dunkindonuts.com` → CNAME → `whitelabel.olo.com` (Cloudflare). |
| E11 | vendor | CardFree | Mobile payments/gift cards. AASA lists `382855Q4EZ.com.cardfree.ddnationalprd`. Team ID: 382855Q4EZ. |
| E12 | vendor | Akamai | CDN for ddmprod platform. CNAME chain: `*.edgekey.net` → `*.dsca.akamaiedge.net`. DigiCert certs. |
| E13 | vendor | Proofpoint | Email security. MX records (`psmtp.com`), SPF (`pphosted.com`), DMARC (`dmarc.has.pphosted.com`). Policy: p=reject. |
| E14 | vendor | DigiCert | Certificate authority for ddmprod platform (ECC SHA384). GeoTrust (subsidiary) for www. |
| E15 | vendor | AWS | Hosts root domain (ALB cookies: AWSALB/AWSALBCORS), Route 53 DNS, ACM certs for root domain. |
| E16 | mobile-app | Dunkin' (iOS) | Bundle: `com.dunkinbrands.otgo` (OTGO = Order To Go). Team ID: `7UARB5Z69S`. App Store ID: 1056813463. App Clips: `com.dunkinbrands.otgo.Clip`. Seller: "Dunkin' Donuts". |
| E17 | service | `mapi-dun.prod.ddmprod.dunkindonuts.com` | Mobile API — primary CN on the ddmprod TLS cert. The backbone API for the Dunkin' mobile app. |
| E18 | service | `ode.prod.ddmprod.dunkindonuts.com` | Order Delivery Engine. On cert SANs (prod + preprod). |
| E19 | service | `swi.prod.ddmprod.dunkindonuts.com` | Unknown service ("SWI"). On cert SANs. Wayback shows 404 in 2024 (possibly deprecated). |
| E20 | service | `dun-assets.prod.ddmprod.dunkindonuts.com` | Static asset CDN. Wayback captured `dunkin_logo@2x.png` (2024). |
| E21 | ad-creative | "Toddler typing" promoted post | Crafted gibberish with 77% home-row keyboard distribution (adult typing pattern). Embedded words: cat, dog, kid, mom, dad, dada. Disguised as organic content to bypass ad fatigue. |
| E22 | org | Dunkin' Brands, Inc. | TLS cert organization. Canton, Massachusetts. Pre-Inspire Brands entity name still on certs. |

## Edges

| From | Relation | To | Evidence |
|------|----------|----|----------|
| E5 | promotes-via | E6 | dunkin2.jpg — "Promoted" label visible |
| E6 | links-to | E2 | urls.txt — `ulink.prod.ddmprod` is the ad click URL |
| E6 | tracks-via | E7 | Wayback: `rdt_cid` parameters on URLs (Reddit Click ID conversion tracking) |
| E6 | targets-by | E21 | `utm_content=interests` — Reddit interest-based ad targeting |
| E2 | mobile-route | E16 | AASA: Universal Links open app directly to `dunkin://orders/category/119` |
| E2 | fallback-route | E9 | Landing page HTML: "Continue on App" → `dunkin.smart.link/f6iexb4x5` (Branch.io) |
| E2 | desktop-redirect | E1 | HTTP 302 to `www.dunkindonuts.com/en/mobile-app` for desktop/bot UAs |
| E2 | hosted-on | E12 | CNAME → `edgekey.net` → `akamaiedge.net` |
| E2 | cert-issued-by | E14 | DigiCert Global G3 TLS ECC SHA384 2020 CA1 |
| E2 | shares-cert-with | E17 | Primary CN is `mapi-dun`, not `ulink` |
| E4 | contains | E2, E3, E17, E18, E19, E20 | Cert SANs + Wayback discovery |
| E4 | managed-by | E22 | Cert O field: "Dunkin' Brands, Inc." |
| E1 | ordering-via | E10 | `order.dunkindonuts.com` → CNAME → `whitelabel.olo.com` |
| E1 | email-via | E13 | MX → psmtp.com, SPF → pphosted.com, DMARC → p=reject |
| E1 | hosted-on | E15 | A records → AWS IPs, ALB cookies, Route 53 NS, ACM certs |
| E1 | owned-by | E8 | Corporate ownership (2020 acquisition) |
| E16 | payments-via | E11 | AASA: `com.cardfree.ddnationalprd` handles `/dunkin/*` paths |
| E8 | parent-of | E22 | Inspire Brands → Dunkin' Brands |

## Clusters

### CL1: ddmprod Platform (Mobile Backend)
- E2 (ulink), E3 (k), E17 (mapi-dun), E18 (ode), E19 (swi), E20 (dun-assets)
- Dunkin's custom mobile application platform, NOT a third-party vendor product
- Hosted on Akamai CDN with DigiCert ECC certs
- Node.js/Express backend (X-Powered-By: Express)
- Two environments: `prod`, `preprod`
- Named "ddmprod" — pre-2018 naming convention ("Dunkin' Donuts Mobile Production")
- Services: Mobile API, Universal Links, Order Delivery Engine, static assets

### CL2: Ad → App Conversion Pipeline
- E5 (u/dunkin) → E6 (Reddit Ads) → E2 (ulink) → E16 (app) or E9 (Branch.io) or E1 (web)
- Three-branch routing based on User-Agent:
  1. Mobile + app installed → iOS Universal Links open app directly
  2. Mobile + no app → Interstitial page → Branch.io smart link → App Store → deferred deep link
  3. Desktop/Bot → 302 redirect to www.dunkindonuts.com/en/mobile-app
- Conversion tracked via Reddit Pixel (`rdt_cid` parameter)
- Targeting: interest-based (`utm_content=interests`)

### CL3: Vendor Stack
- E9 (Branch.io) — deep linking
- E10 (OLO) — online ordering
- E11 (CardFree) — mobile payments
- E12 (Akamai) — CDN for mobile platform
- E13 (Proofpoint) — email security
- E14 (DigiCert) — TLS certificates
- E15 (AWS) — hosting, DNS, root domain certs

### CL4: www Infrastructure (non-ddmprod)
- Separate Akamai config (`e5079.a.akamaiedge.net` vs `e36726.dsca.akamaiedge.net`)
- GeoTrust cert (DigiCert subsidiary) with 44 SANs including:
  - SDLC environments: dev2, qa, qa2, staging, staging3, uat
  - SSO: ssoprd, ssostg, social-sso (prd/preprod/stg)
  - Menu pricing: menu-pricing-prd/prd1/stg
  - QR menus: qrmenu, qrmenu-stg (dunkinbrands.com)
  - Franchisee portal: franchiseecentral.dunkinbrands.com
  - Cross-brand: baskinrobbins.com (www, staging, staging2, qa, www2)
  - Other: loyalty, star, afm, fps (dunkinbrands.com)
- Backend on AWS ALB (AWSALB cookies)

## Anomalies

| ID | Description | Status |
|----|-------------|--------|
| A1 | Gibberish text is crafted ad copy: 77% home-row keyboard distribution, embedded family words (cat, dog, kid, mom, dad). NOT encoded data. | **Resolved** — adult copywriter, not toddler |
| A2 | Double "prod" in `prod.ddmprod` — legacy naming, "ddmprod" is the platform name from pre-2018 era | **Resolved** — confirmed legacy naming |
| A3 | `k.prod.ddmprod` does not resolve via external DNS but appears in user's browser bar | Partially resolved — behind Akamai, may be served via App Clip or edge-internal routing |
| A4 | www cert contains 44 SANs exposing full SDLC environment topology (dev, qa, staging, uat) | Noted — significant infrastructure exposure via cert transparency |
| A5 | Cert CN is `mapi-dun` but serves `ulink` — all ddmprod services share one cert | Noted — single cert for all platform services |

## Resolved Questions

- [x] **What deep linking vendor?** → Branch.io (`dunkin.smart.link/f6iexb4x5`)
- [x] **What CDN?** → Akamai (ddmprod: `e36726.dsca.akamaiedge.net`, www: `e5079.a.akamaiedge.net`)
- [x] **Reddit targeting method?** → Interest-based (`utm_content=interests`, `utm_medium=paidsocial`)
- [x] **What is ddmprod?** → "Dunkin' Donuts Mobile Production" — custom in-house mobile platform, NOT a third-party product
- [x] **Is gibberish encoded?** → No. Crafted ad copy. 77% home-row keys, embedded family words.

## Open Questions

- [ ] What is `swi` in the ddmprod platform? (Wayback shows 404 — possibly deprecated)
- [ ] What is category 119 specifically? (All categories 100-130 return 302 — wildcard routing)
- [ ] Do Inspire Brands sister brands (Arby's, BWW, Sonic) use similar `ddmprod`-style platforms?
- [ ] What specific Reddit interest categories triggered this ad?

## Evidence Index

| Artifact | Location | Description |
|----------|----------|-------------|
| dunkin1.jpg | `intake-2026-04-13/` | Reddit post — 0 Sugar Tropical Mango ad |
| dunkin2.jpg | `intake-2026-04-13/` | Reddit promoted post — crafted "toddler" gibberish |
| dunkin3.jpg | `intake-2026-04-13/` | Landing page — app interstitial on k.prod.ddmprod |
| urls.txt | `intake-2026-04-13/` | Target URL from ad click |
| results.txt | `artifacts/dns-enum-2026-04-13/` | DNS enumeration raw output |
| results.txt | `artifacts/http-probe-2026-04-13/` | HTTP probing raw output |
| results.txt | `artifacts/cert-analysis-2026-04-13/` | Certificate analysis raw output |
| results.txt | `artifacts/osint-2026-04-13/` | OSINT raw output (whois, Wayback, iTunes, Reddit API, nmap) |
| results.txt | `artifacts/gibberish-analysis-2026-04-13/` | Gibberish text analysis raw output |
