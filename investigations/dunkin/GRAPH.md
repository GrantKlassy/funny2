# Dunkin' Ad Infrastructure Investigation

> Started: 2026-04-13
> Status: Active — expanded probing complete
> Last probed: 2026-04-13T20:11Z

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
| E8 | parent-company | Inspire Brands | Acquired Dunkin' Brands 2020. Parent of Dunkin', Baskin-Robbins, Arby's, Buffalo Wild Wings, Sonic, Jimmy John's. |
| E9 | vendor | Branch.io | Deep linking vendor. Smart links at `dunkin.smart.link` (GCP 34.36.249.118). Link ID: `f6iexb4x5`. Runs on Kubernetes/Istio service mesh (x-envoy-decorator: inboarder.links-inboarder.svc.cluster.local). `dunkin.app.link` on CloudFront. |
| E10 | vendor | OLO | Online ordering platform. `order.dunkindonuts.com` → CNAME → `whitelabel.olo.com` (Cloudflare). |
| E11 | vendor | CardFree | Mobile payments AND full app development. iOS: `382855Q4EZ.com.cardfree.ddnationalprd`. Android: `com.cardfree.android.dunkindonuts` (DEV/UAT/prod builds). Single signing key across environments. |
| E12 | vendor | Akamai | CDN for ddmprod platform AND www infrastructure. ddmprod: `e36726.dsca.akamaiedge.net`. www/SANs: `e5079.{a,b,dsca}.akamaiedge.net`. Separate staging config: `edgekey-staging.net` for mapi-dun.preprod. |
| E13 | vendor | Proofpoint | Email security. MX records (`psmtp.com`), SPF (`pphosted.com`), DMARC (`dmarc.has.pphosted.com`). Policy: p=reject. |
| E14 | vendor | DigiCert | Certificate authority for ddmprod platform (ECC SHA384). GeoTrust (subsidiary) for www cert (47 SANs). |
| E15 | vendor | AWS | Hosts root domain (ALB cookies: AWSALB/AWSALBCORS), Route 53 DNS, ACM certs. Also hosts: QA env (direct, no Akamai), vanity domains (ALB), franchisee portal backend. |
| E16 | mobile-app | Dunkin' (iOS) | Bundle: `com.dunkinbrands.otgo` (OTGO = Order To Go). Team ID: `7UARB5Z69S`. App Store ID: 1056813463. App Clips: `com.dunkinbrands.otgo.Clip`. Seller: "Dunkin' Donuts". |
| E17 | service | `mapi-dun.prod.ddmprod.dunkindonuts.com` | Mobile API — primary CN on the ddmprod TLS cert. The backbone API for the Dunkin' mobile app. Preprod uses Akamai staging config (`edgekey-staging.net`). |
| E18 | service | `ode.prod.ddmprod.dunkindonuts.com` | Order Delivery Engine. On cert SANs (prod only — preprod does NOT resolve, possibly decommissioned). |
| E19 | service | `swi.prod.ddmprod.dunkindonuts.com` | Unknown service ("SWI"). On cert SANs. Wayback shows 404 in 2024 (deprecated). Preprod still resolves via Akamai. |
| E20 | service | `dun-assets.prod.ddmprod.dunkindonuts.com` | Static asset CDN. Wayback captured `dunkin_logo@2x.png` (2024). |
| E21 | ad-creative | "Toddler typing" promoted post | Crafted gibberish with 77% home-row keyboard distribution (adult typing pattern). Embedded words: cat, dog, kid, mom, dad, dada. Disguised as organic content to bypass ad fatigue. |
| E22 | org | Dunkin' Brands, Inc. | TLS cert organization. Canton, Massachusetts. Pre-Inspire Brands entity name still on certs. |
| E23 | service | `cloud-preprod.ddmprod.dunkindonuts.com` | Cloud infrastructure service (preprod only). CNAME → `d25cpty3ekbo1l.cloudfront.net` — runs on CloudFront, NOT Akamai. Different CDN strategy than prod. Wayback: 403 in 2023. |
| E24 | vendor | Tillster | Online ordering for Baskin-Robbins. `order.baskinrobbins.com` → `www-br-us.tillster.com` → CloudFront. Different vendor than Dunkin' (which uses OLO). |
| E25 | domain | `dunkinbrands.com` | Corporate domain. A: 130.211.9.50 (GCP — different from all other Dunkin' infra). 931 CT log entries exposing massive internal infrastructure. |
| E26 | service | `www.dunkinbrands.com` | Investor relations site. CNAME → `dunkinbrands.com.iprsoftware.com` (IPR Software platform). Hosted on GCP (35.190.35.217). |
| E27 | vendor | IPR Software | Investor relations platform. Hosts `www.dunkinbrands.com`. |
| E28 | domain | `dunkinrun.com` | Campaign vanity domain. Redirect chain: 301 → www.dunkinrun.com → 302 → www.dunkindonuts.com. AWS ALB. Campaign name `dunkinrun` in UTM parameters. |
| E29 | service | `franchiseecentral.dunkinbrands.com` | Franchisee portal. Cloudflare CDN → ASP.NET + AWSALB backend. Last-modified: 2016-07-12 (10 years old!). |
| E30 | service | `ssoprd.dunkindonuts.com` | SSO production service. Live (HTTP 200). 149 bytes, behind Akamai. Last-modified: 2025-07-31. X-Frame-Options: DENY. |
| E31 | service | `menu-pricing-prd.dunkindonuts.com` | Menu pricing REST API. Returns JSON 404 with Spring Boot security headers (HSTS, X-Content-Type-Options, X-Frame-Options). Behind Akamai. |
| E32 | service | `qrmenu.dunkinbrands.com` | QR menu service. Kestrel server (ASP.NET Core). HTTP 404. AWS hosted. |
| E33 | service | `star.dunkinbrands.com` | Unknown service ("STAR"). Returns HTTP 405 (Method Not Allowed). Behind Akamai. |
| E34 | mobile-app | Dunkin' (Android) | Package: `com.cardfree.android.dunkindonuts`. Built by CardFree. Environments: DEV, UAT, prod. Single signing key (SHA256: CE:A1:...:D8:64). Android Asset Links on ulink.prod.ddmprod. |
| E35 | portal | `franchising.inspirebrands.com` | Centralized Inspire Brands franchising portal. Both `dunkinfranchising.com` and `baskinrobbinsfranchising.com` redirect here. Cloudflare hosted. |
| E36 | domain | `baskinrobbins.com` | Sister brand domain. Shares A records (52.0.33.13, 35.169.92.22), AWS Route 53, AND the www TLS cert (47 SANs) with dunkindonuts.com. Literally the same infrastructure. |
| E37 | service | `fps.dunkinbrands.com` | Unknown service ("FPS"). AWS ELB: `caas-prod-dunkinbrands-com`. "CAAS" = Content As A Service? Connection refused. |
| E38 | ct-exposure | dunkinbrands.com CT logs | 931 cert entries exposing: Citrix, VPN (SSL/web/password), VDI, Xen, IBM collab (QuickPlace/Quickr/iNotes), Genesis platform, SmartSolve EQMS, PLM, RBOS, POSHC, STS, 3 smartphone mgmt endpoints. Email leak: terry.ursino@dunkinbrands.com in cert CN. |
| E39 | vendor | Cloudflare | CDN for franchisee portal, franchising redirects, dunkinfranchising.com, baskinrobbinsfranchising.com. |

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
| E2 | android-links | E34 | assetlinks.json lists CardFree Android packages (DEV/UAT) |
| E4 | contains | E2, E3, E17, E18, E19, E20, E23 | Cert SANs + Wayback + DNS discovery |
| E4 | managed-by | E22 | Cert O field: "Dunkin' Brands, Inc." |
| E1 | ordering-via | E10 | `order.dunkindonuts.com` → CNAME → `whitelabel.olo.com` |
| E1 | email-via | E13 | MX → psmtp.com, SPF → pphosted.com, DMARC → p=reject |
| E1 | hosted-on | E15 | A records → AWS IPs, ALB cookies, Route 53 NS, ACM certs |
| E1 | owned-by | E8 | Corporate ownership (2020 acquisition) |
| E1 | shares-infra-with | E36 | Same A records (52.0.33.13, 35.169.92.22), same www cert (47 SANs), same Route 53 |
| E16 | payments-via | E11 | AASA: `com.cardfree.ddnationalprd` handles `/dunkin/*` paths |
| E16 | built-by | E11 | CardFree develops entire Dunkin' mobile app (iOS + Android) |
| E34 | built-by | E11 | assetlinks.json: `com.cardfree.android.dunkindonuts` (DEV/UAT/prod) |
| E8 | parent-of | E22 | Inspire Brands → Dunkin' Brands |
| E8 | operates | E35 | Central franchising portal for all brands |
| E8 | parent-of | E36 | Inspire Brands → Baskin-Robbins |
| E23 | hosted-on-cloudfront | E15 | CNAME → `d25cpty3ekbo1l.cloudfront.net` (AWS CloudFront, NOT Akamai) |
| E36 | ordering-via | E24 | `order.baskinrobbins.com` → `www-br-us.tillster.com` → CloudFront |
| E25 | ct-exposes | E38 | 931 CT log entries from crt.sh reveal massive internal infrastructure |
| E25 | investor-relations-via | E27 | www.dunkinbrands.com → iprsoftware.com |
| E28 | redirects-to | E1 | dunkinrun.com → 301/302 chain → www.dunkindonuts.com |
| E28 | campaign-name | E6 | `utm_campaign=dunkinrun` matches domain name |
| E29 | hosted-on | E39 | Cloudflare CDN → ASP.NET backend on AWSALB |
| E30 | hosted-on | E12 | Behind Akamai (ssoprd.dunkindonuts.com.edgekey.net) |
| E31 | hosted-on | E12 | Behind Akamai, returns JSON (Spring Boot REST API) |
| E32 | hosted-on | E15 | AWS (Kestrel/ASP.NET Core) |
| E33 | hosted-on | E12 | Behind Akamai, returns 405 |

## Clusters

### CL1: ddmprod Platform (Mobile Backend)
- E2 (ulink), E3 (k), E17 (mapi-dun), E18 (ode), E19 (swi), E20 (dun-assets), E23 (cloud-preprod)
- Dunkin's custom mobile application platform, NOT a third-party vendor product
- Hosted on Akamai CDN with DigiCert ECC certs (prod)
- **Preprod split**: mapi-dun.preprod uses `edgekey-staging.net` (Akamai staging), cloud-preprod and dun-assets.preprod use CloudFront
- Node.js/Express backend (X-Powered-By: Express)
- Two environments: `prod`, `preprod`
- Named "ddmprod" — pre-2018 naming convention ("Dunkin' Donuts Mobile Production")
- Services: Mobile API, Universal Links, Order Delivery Engine, static assets, cloud infra

### CL2: Ad → App Conversion Pipeline
- E5 (u/dunkin) → E6 (Reddit Ads) → E2 (ulink) → E16 (app) or E9 (Branch.io) or E1 (web)
- E28 (dunkinrun.com) — campaign vanity domain matching `utm_campaign=dunkinrun`
- Three-branch routing based on User-Agent:
  1. Mobile + app installed → iOS Universal Links open app directly
  2. Mobile + no app → Interstitial page → Branch.io smart link → App Store → deferred deep link
  3. Desktop/Bot → 302 redirect to www.dunkindonuts.com/en/mobile-app
- Conversion tracked via Reddit Pixel (`rdt_cid` parameter)
- Targeting: interest-based (`utm_content=interests`)

### CL3: Vendor Stack
- E9 (Branch.io) — deep linking (GCP + CloudFront, Kubernetes/Istio)
- E10 (OLO) — online ordering for Dunkin' (`whitelabel.olo.com`)
- E11 (CardFree) — mobile app development + payments (iOS + Android, all environments)
- E12 (Akamai) — CDN for mobile platform + www (two configs: e36726 for ddmprod, e5079 for www)
- E13 (Proofpoint) — email security
- E14 (DigiCert) — TLS certificates (ECC for ddmprod, GeoTrust/RSA for www)
- E15 (AWS) — hosting, DNS, ALB, Route 53, ACM certs, CloudFront for some preprod services
- E24 (Tillster) — online ordering for Baskin-Robbins (different vendor than Dunkin')
- E27 (IPR Software) — investor relations (dunkinbrands.com)
- E39 (Cloudflare) — CDN for franchising portals

### CL4: www Infrastructure (non-ddmprod)
- Akamai config `e5079.{a,b,dsca}.akamaiedge.net` (shared across www, staging, dev, qa, SSO, menu-pricing, cross-brand)
- GeoTrust cert (DigiCert subsidiary) with 47 SANs including:
  - SDLC environments: dev2, qa, qa2, staging, staging3, uat
  - SSO: ssoprd (LIVE, 200), ssostg (LIVE, 200), social-sso (prd/preprod/stg)
  - Menu pricing API: menu-pricing-prd (JSON 404, Spring Boot), menu-pricing-stg
  - QR menus: qrmenu, qrmenu-stg (dunkinbrands.com)
  - Franchisee portal: franchiseecentral.dunkinbrands.com (ASP.NET, Cloudflare+AWSALB)
  - Cross-brand: baskinrobbins.com (www, staging, staging2, qa, www2)
  - Other: loyalty, star (405 API), afm, fps (AWS ELB "caas-prod"), dunkinbrands.com subdomains
- Backend on AWS ALB (AWSALB cookies)
- Notable: QA env (qa.dunkindonuts.com) goes DIRECT to AWS (52.71.129.172), bypassing Akamai

### CL5: Inspire Brands Corporate
- E8 (Inspire Brands) — parent company
- E22 (Dunkin' Brands, Inc.) — pre-acquisition entity, name persists on certs
- E35 (franchising.inspirebrands.com) — centralized franchising portal
- dunkinfranchising.com → franchising.inspirebrands.com/dunkin
- baskinrobbinsfranchising.com → franchising.inspirebrands.com/baskin-robbins
- Sister brands use completely different infrastructure (no ddmprod):
  - Arby's: Cloudflare, Let's Encrypt
  - BWW: CSC DNS, Let's Encrypt
  - Sonic: CSC DNS, Google Trust Services, Cloudflare ordering
  - Jimmy John's: Cloudflare, Google Trust Services, own AASA

### CL6: Baskin-Robbins Infrastructure
- E36 (baskinrobbins.com) — shares A records AND www cert with dunkindonuts.com
- E24 (Tillster) — ordering vendor (different from Dunkin's OLO)
- Same AWS IPs: 52.0.33.13, 35.169.92.22
- Same Route 53 nameservers
- Same GeoTrust cert (47 SANs)
- No AASA (no iOS deep linking, unlike Dunkin')
- Staging (54.87.41.104) and QA (Akamai) environments exist

### CL7: dunkinbrands.com Legacy Infrastructure
- E25 (dunkinbrands.com) — corporate domain on GCP (130.211.9.50)
- E26 (www.dunkinbrands.com) — investor relations on IPR Software
- E29 (franchiseecentral) — Cloudflare + ASP.NET + AWSALB (last-modified 2016!)
- E38 (CT logs) — 931 entries exposing pre-Inspire internal infrastructure:
  - Remote access: Citrix, SSL VPN (x2), web VPN, password VPN
  - Virtualization: VDI, Xen
  - Internal apps: "The Center" portal, Genesis platform, RBOS, POSHC, SmartSolve EQMS
  - IBM stack: QuickPlace, Quickr, iNotes (legacy collaboration)
  - Security: STS, identity provider (flq-prod-idp)
  - Supply chain: PLM, strategic supply
  - Mobile: 3 smartphone management endpoints
  - Email leak: terry.ursino@dunkinbrands.com in cert CN

### CL8: Vanity Domains
- E28 (dunkinrun.com) — campaign domain, redirects to dunkindonuts.com
- dunkinrewards.com — AWS ALB redirect
- dunkinemail.com — AWS ALB redirect
- ddperks.com — AWS ALB redirect (pre-rebrand loyalty program name)
- dunkinperks.com — AWS ALB redirect
- ddglobalfranchising.com — same IPs as dunkindonuts.com root
- dunkinnation.com — AWS, connection refused
- All served from shared AWS ALB pool (35.153.79.184, 35.173.143.243)

## Anomalies

| ID | Description | Status |
|----|-------------|--------|
| A1 | Gibberish text is crafted ad copy: 77% home-row keyboard distribution, embedded family words (cat, dog, kid, mom, dad). NOT encoded data. | **Resolved** — adult copywriter, not toddler |
| A2 | Double "prod" in `prod.ddmprod` — legacy naming, "ddmprod" is the platform name from pre-2018 era | **Resolved** — confirmed legacy naming |
| A3 | `k.prod.ddmprod` does not resolve via external DNS but appears in user's browser bar | Partially resolved — behind Akamai, may be served via App Clip or edge-internal routing |
| A4 | www cert contains 47 SANs (originally counted 44) exposing full SDLC environment topology | **Confirmed** — nearly all SANs resolve and are live. QA bypasses Akamai. UAT on different IP (216.255.76.18). |
| A5 | Cert CN is `mapi-dun` but serves `ulink` — all ddmprod services share one cert | **Confirmed** — single cert for all platform services |
| A6 | ddmprod preprod uses MIXED CDN: Akamai for ulink/swi, Akamai Staging for mapi-dun, CloudFront for cloud/dun-assets | **New** — hybrid CDN strategy, preprod is split across vendors |
| A7 | baskinrobbins.com resolves to IDENTICAL A records and shares www cert with dunkindonuts.com | **New** — they are literally the same infrastructure |
| A8 | CardFree builds the ENTIRE Dunkin' mobile app (iOS + Android), not just payments | **New** — assetlinks.json exposes DEV/UAT packages. AASA already showed iOS. |
| A9 | `terry.ursino@dunkinbrands.com` leaked into CT logs as cert CN | **New** — personal email in cert transparency, likely a test cert that was logged |
| A10 | franchiseecentral.dunkinbrands.com last-modified 2016-07-12 — static content unchanged for 10 years | **New** — possibly legacy/abandoned portal |
| A11 | Branch.io leaks Kubernetes internal service topology: `inboarder.links-inboarder.svc.cluster.local` | **New** — istio-envoy x-envoy-decorator-operation header |

## Resolved Questions

- [x] **What deep linking vendor?** → Branch.io (`dunkin.smart.link/f6iexb4x5`)
- [x] **What CDN?** → Akamai (ddmprod: `e36726.dsca.akamaiedge.net`, www: `e5079.a.akamaiedge.net`)
- [x] **Reddit targeting method?** → Interest-based (`utm_content=interests`, `utm_medium=paidsocial`)
- [x] **What is ddmprod?** → "Dunkin' Donuts Mobile Production" — custom in-house mobile platform, NOT a third-party product
- [x] **Is gibberish encoded?** → No. Crafted ad copy. 77% home-row keys, embedded family words.
- [x] **Do Inspire Brands sister brands use ddmprod?** → No. ddmprod is unique to Dunkin'. Each brand has completely different infrastructure.

## Open Questions

- [ ] What is `swi` in the ddmprod platform? (Preprod still resolves but prod shows 404 — deprecated service)
- [ ] What is category 119 specifically? (All categories 100-130 return 302 — wildcard routing)
- [ ] What specific Reddit interest categories triggered this ad?
- [ ] What is `star.dunkinbrands.com`? (Returns 405 — API-only, method restricted)
- [ ] What is `fps.dunkinbrands.com`? (AWS ELB "caas-prod", connection refused)
- [ ] Who is Terry Ursino? (Email leaked in CT logs)
- [ ] What is the Genesis platform? (genesisproduction/genesissandbox.dunkinbrands.com)
- [ ] What is RBOS? (rbos.dunkinbrands.com — Restaurant Business Operating System?)

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
| results.txt | `artifacts/sister-brands-2026-04-13/` | Inspire Brands sister brand infrastructure comparison |
| results.txt | `artifacts/www-cert-sans-2026-04-13/` | www cert SAN resolution + brand domain probing |
| results.txt | `artifacts/ddmprod-deep-dive-2026-04-13/` | ddmprod preprod, CT logs, Branch.io, OLO, Android Asset Links |
