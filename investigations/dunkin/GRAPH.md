# Dunkin' Ad Infrastructure Investigation

> Started: 2026-04-13
> Status: Active — Wave 2 probing complete
> Last probed: 2026-04-13T21:00Z

## Trigger

Highly targeted Reddit promoted ad from `u/dunkin` using fake "toddler keyboard smashing" creative. Clicking the ad navigated to `ulink.prod.ddmprod.dunkindonuts.com`, a custom Universal Links service that routes mobile users to the Dunkin' app via Branch.io and desktop users to `www.dunkindonuts.com`. The deep subdomain naming exposed Dunkin's entire mobile backend platform.

## Entities

| ID | Type | Name | Notes |
|----|------|------|-------|
| E1 | domain | `dunkindonuts.com` | Root domain, registered 1995-07-13. Pre-2018 rebrand naming retained. AWS Route 53 NS, CSC Corporate Domains registrar. |
| E2 | service | `ulink.prod.ddmprod.dunkindonuts.com` | Universal Links router. Node.js/Express behind Akamai CDN. UA-based routing: mobile→200 interstitial, desktop/bot→302 to www. |
| E3 | service | `k.prod.ddmprod.dunkindonuts.com` | Does not resolve externally via DNS. Accessed only behind Akamai edge. Serves app interstitial (seen in dunkin3.jpg browser bar). |
| E4 | platform | `ddmprod` | "Dunkin' Donuts Mobile Production" — internal mobile app platform. Contains: mapi-dun (Mobile API), ulink (Universal Links), ode (Order Delivery Engine), swi (active in dev/QA), k (web kickout), dun-assets (static CDN), cloud (infra). Environments: prod, preprod, stage. Sibling platform: ddmdev (development). |
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
| E19 | service | `swi.prod.ddmprod.dunkindonuts.com` | Unknown service ("SWI"). LIVE in prod (Akamai), preprod, AND all ddmdev environments (dev, dlt-dev, dlt-qa, qa). Not deprecated — actively maintained across 6+ environments. Prod 404 may just be no default route. |
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
| E30 | service | `ssoprd.dunkindonuts.com` | Legacy DD Perks "Sip. Peel. Win Sweepstakes" login page. 149-byte body says "Application is running" + Akamai mPulse RUM. `/login` serves a form asking for DD Perks email/password. All OIDC discovery paths 302. Separate from social-sso (modern OAuth2). |
| E31 | service | `menu-pricing-prd.dunkindonuts.com` | Menu pricing REST API. Returns JSON 404 with Spring Boot security headers (HSTS, X-Content-Type-Options, X-Frame-Options). Behind Akamai. |
| E32 | service | `qrmenu.dunkinbrands.com` | QR menu service. Kestrel server (ASP.NET Core). HTTP 404. AWS hosted. |
| E33 | service | `star.dunkinbrands.com` | Unknown service ("STAR"). GET returns 200, HEAD returns 405, Allow: GET only. Behind Akamai (`e5079`). Has staging variant (`star-stg.dunkinbrands.com` on cert). All other paths return 404. POST requires Content-Length (411). |
| E34 | mobile-app | Dunkin' (Android) | Package: `com.cardfree.android.dunkindonuts`. Built by CardFree. Environments: DEV, UAT, prod. Single signing key (SHA256: CE:A1:...:D8:64). Android Asset Links on ulink.prod.ddmprod. |
| E35 | portal | `franchising.inspirebrands.com` | Centralized Inspire Brands franchising portal. Both `dunkinfranchising.com` and `baskinrobbinsfranchising.com` redirect here. Cloudflare hosted. |
| E36 | domain | `baskinrobbins.com` | Sister brand domain. Shares A records (52.0.33.13, 35.169.92.22), AWS Route 53, AND the www TLS cert (47 SANs) with dunkindonuts.com. Literally the same infrastructure. |
| E37 | service | `fps.dunkinbrands.com` | DEAD. Shares CNAME with rbos.dunkinbrands.com → same ELB: `caas-prod-dunkinbrands-com-261297133.us-east-1.elb.amazonaws.com`. CAAS platform decommissioned. All ports closed. |
| E38 | ct-exposure | dunkinbrands.com CT logs | 931 cert entries exposing: Citrix, VPN (SSL/web/password), VDI, Xen, IBM collab (QuickPlace/Quickr/iNotes), Genesis platform, SmartSolve EQMS, PLM, RBOS, POSHC, STS, 3 smartphone mgmt endpoints. Email leak: terry.ursino@dunkinbrands.com in cert CN. |
| E39 | vendor | Cloudflare | CDN for franchisee portal, franchising redirects, dunkinfranchising.com, baskinrobbinsfranchising.com. |
| E40 | platform | `ddmdev` | "Dunkin' Donuts Mobile Development" — separate dev platform from ddmprod. Sub-environments: dev, dlt-dev, dlt-qa, qa. Has its own Akamai edgekey configs. Services mirror ddmprod: ulink, mapi-dun, ode, swi. |
| E41 | service | `swagger.ddmdev.dunkindonuts.com` | Swagger API documentation. LIVE at 34.237.71.65 (bare AWS, no CDN). Potentially exposes full mobile API specification. |
| E42 | service | `auth0-stg.dunkindonuts.com` | Auth0 staging. CNAME → AWS API Gateway (`d-7p5rilj85g.execute-api.us-east-1.amazonaws.com`). Suggests Auth0 was considered/used for authentication. |
| E43 | sso | Spring Authorization Server | Modern OAuth2/OIDC SSO. OIDC discovery exposed on social-sso (prd/preprod/stg) and ssostg. Supports: auth code, client credentials, refresh token, device auth, token exchange. PKCE (S256), DPoP, mTLS. |
| E44 | vendor | ServiceNow | Customer service platform. `chat.dunkindonuts.com` → `inspirecustomer.service-now.com`. Dev/test instances exist (`chatdev`→`inspirecustomerdev`, `chattest`→`inspirecustomertest`). |
| E45 | vendor | Paradox AI | AI-powered recruiting. `careers.dunkindonuts.com` → `careers-dunkindonuts-com.sites.paradox.ai`. |
| E46 | vendor | Adobe Analytics | Web analytics. `smetrics.dunkindonuts.com` → `dunkindonuts.com.102.122.2o7.net` (Omniture/Adobe). |
| E47 | vendor | Salesforce Marketing Cloud | Email marketing. `emailinfo.dunkindonuts.com` subdomains (click, cloud, image, view) → Salesforce SFMC content servers. |
| E48 | service | POS API cluster | Point of Sale APIs on AWS API Gateway. `pos-api.dunkindonuts.com`, `pos-ws.dunkindonuts.com`, `opc-api.dunkindonuts.com`, `dbapi-ws.dunkindonuts.com`. All CNAME to `execute-api.us-east-1.amazonaws.com`. |
| E49 | service | `international.dunkindonuts.com` | International Dunkin' site. A: 20.74.242.116 — Azure (Microsoft), completely different cloud from all other Dunkin' infrastructure. |
| E50 | service | `thecenter.dunkinbrands.com` | Internal portal. CNAME → `d1zthqe9odn0bu.cloudfront.net` (CloudFront). Returns 200 on GET/POST/PUT. Accepts all methods. |
| E51 | service | `recognition.dunkinbrands.com` | Employee recognition platform. CNAME → `dunkin-brands.werecognize.com` (WeRecognize). 302 redirect on access. |
| E52 | service | `rbos.dunkinbrands.com` | DEAD. Same CAAS ELB as fps (caas-prod-dunkinbrands-com). "Restaurant Business Operating System" — decommissioned with fps. |
| E53 | service | `flq-prod-idp.dunkinbrands.com` | Identity Provider. A: 74.199.217.23. GET returns 302 (redirect to login). Same subnet as smartsolve (74.199.217.x). |
| E54 | service | `login.dunkindonuts.com` | Login portal. A: 104.18.32.124 (Cloudflare). |
| E55 | service | `api-idp.dunkindonuts.com` | Identity Provider API. A: 104.18.32.226 (Cloudflare). |
| E56 | vendor | IBM Cloud Managed App Services | Hosts UAT environment. `uat.dunkindonuts.com` → 216.255.76.18 (Verizon Business / DIGEX-BLK-2 / IBM ICMAS network). UAT is completely unresponsive. |

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
| E40 | sibling-of | E4 | ddmdev is development counterpart to ddmprod; mirrors services (ulink, mapi-dun, ode, swi) |
| E40 | hosted-on | E12 | ddmdev services use Akamai edgekey.net CNAMEs |
| E41 | part-of | E40 | swagger.ddmdev is the API docs service for the ddmdev platform |
| E41 | hosted-on | E15 | Bare AWS IP 34.237.71.65, NO CDN — exposed directly |
| E42 | hosted-on | E15 | CNAME → `d-7p5rilj85g.execute-api.us-east-1.amazonaws.com` (API Gateway) |
| E43 | serves | E30 | ssostg OIDC discovery exposed (ssoprd is legacy DD Perks, NOT Spring Auth) |
| E43 | serves-auth-for | E1 | social-sso (prd/preprod/stg) all expose OIDC discovery — modern auth for dunkindonuts.com |
| E44 | serves | E1 | `chat.dunkindonuts.com` → `inspirecustomer.service-now.com` |
| E45 | serves | E1 | `careers.dunkindonuts.com` → `careers-dunkindonuts-com.sites.paradox.ai` |
| E46 | tracks | E1 | `smetrics.dunkindonuts.com` → `dunkindonuts.com.102.122.2o7.net` (Adobe/Omniture) |
| E47 | emails-for | E1 | `emailinfo.dunkindonuts.com` subdomains (click, cloud, image, view) → Salesforce SFMC |
| E48 | hosted-on | E15 | All POS APIs CNAME to `execute-api.us-east-1.amazonaws.com` (API Gateway) |
| E49 | hosted-on-azure | — | A: 20.74.242.116 — Microsoft Azure, different cloud from all other Dunkin' infra |
| E50 | hosted-on | E15 | CNAME → `d1zthqe9odn0bu.cloudfront.net` (CloudFront) |
| E51 | hosted-on-external | — | CNAME → `dunkin-brands.werecognize.com` (third-party platform) |
| E52 | shares-elb-with | E37 | Both CNAME to `caas-prod-dunkinbrands-com-261297133.us-east-1.elb.amazonaws.com` |
| E53 | same-subnet-as | E25 | 74.199.217.23 — same /24 as smartsolve.dunkinbrands.com (74.199.217.32) |
| E54 | hosted-on | E39 | A: 104.18.32.124 (Cloudflare) |
| E55 | hosted-on | E39 | A: 104.18.32.226 (Cloudflare) |
| E56 | hosts | E1 | UAT environment at 216.255.76.18 — Verizon Business / DIGEX / IBM ICMAS network |

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
- Vanity `www.*` variants CNAME to `san.dunkinbrands.com.edgekey.net` (Akamai e5079)
- TLS cert for vanity pool (dunkinrun.com CN) also covers: clubdunkin.com, `*.dunkinbrands.com`, `*.dunkindonuts.co.uk`, ddperks.com, dunkinperks.com
- Separate cert for dunkinnation/brglobalfranchising covers: `*.dnkn.com`, `*.lsmnow.com`, catering.dunkindonuts.com, staging.dunkinfranchising.com

### CL9: Identity & Auth
- E30 (ssoprd) — legacy DD Perks "Sip. Peel. Win" sweepstakes login (Java backend, JSESSIONID-style)
- E43 (Spring Authorization Server) — modern OAuth2/OIDC, exposed on social-sso (prd/preprod/stg) + ssostg
  - Full OIDC discovery: auth code, client credentials, refresh, device auth, token exchange
  - PKCE (S256), DPoP, mTLS, pushed authorization requests (PAR)
  - Token endpoint oddity: `/oauth/token` (no `2`) vs `/oauth2/` for everything else
- E42 (auth0-stg) — Auth0 staging on AWS API Gateway, suggests Auth0 was evaluated/used
- E53 (flq-prod-idp) — dunkinbrands.com identity provider (74.199.217.23), 302 to login
- E54 (login.dunkindonuts.com) — Cloudflare (104.18.32.124)
- E55 (api-idp.dunkindonuts.com) — Cloudflare (104.18.32.226)
- Three generations of auth: legacy Java (ssoprd), Spring Auth Server (social-sso), and Auth0 (staging)

### CL10: ddmdev Platform (Mobile Development)
- E40 (ddmdev) — separate dev platform from ddmprod
- E41 (swagger.ddmdev) — Swagger API docs, bare AWS 34.237.71.65, no CDN
- Sub-environments: dev, dlt-dev, dlt-qa, qa (DLT = "Developer Load Test"?)
- Services mirror ddmprod: ulink, mapi-dun (as `akam-mapi-dun`), ode, swi
- All services use Akamai edgekey.net CNAMEs per-environment
- Parent domains (ddmdev.dunkindonuts.com, dlt-dev.ddmdev, qa.ddmdev) do NOT resolve — only service subdomains do
- Also had: cfdev, ctsdev, dddev, dbiddmobileprod — all now DEAD

### CL11: Legacy Managed Services (dunkinbrands.com)
- E33 (star) — unknown service, GET-only, Akamai e5079, has staging variant star-stg
- E37 (fps) + E52 (rbos) — dead CAAS platform (`caas-prod-dunkinbrands-com` ELB), all ports closed
- E50 (thecenter) — internal portal, CloudFront, accepts GET/POST/PUT (permissive)
- E51 (recognition) — employee recognition via WeRecognize third-party
- E53 (flq-prod-idp) — identity provider, 74.199.217.x subnet (shared with smartsolve)
- E29 (franchiseecentral) — Cloudflare + ASP.NET + AWSALB, last-modified 2016
- Legacy infrastructure on 74.199.217.x subnet: flq-prod-idp (.23), smartsolve (.32) — likely same managed hosting provider
- Two services confirmed dead: fps, rbos (CAAS). Genesis also dead (genesisproduction, genesissandbox both NXDOMAIN).

### CL12: SaaS Vendor Services
- E44 (ServiceNow) — customer chat (`inspirecustomer.service-now.com`), has dev + test instances
- E45 (Paradox AI) — recruiting/careers
- E46 (Adobe Analytics) — web analytics (Omniture/2o7.net)
- E47 (Salesforce Marketing Cloud) — email marketing (click/cloud/image/view subdomains)
- All accessed via dunkindonuts.com CNAME aliases
- ServiceNow instance named "inspirecustomer" — Inspire Brands level, not Dunkin' specific

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
| A12 | QA environment (qa.dunkindonuts.com) uses Amazon RSA wildcard cert (`*.dunkindonuts.com`) with `*.awsprd`, `*.awsstg`, `*.awspt` SANs — completely different cert from GeoTrust 47-SAN used everywhere else | **New** — QA is a separate AWS deployment with its own cert, bypasses Akamai |
| A13 | ssoprd.dunkindonuts.com is NOT modern SSO — it's a legacy DD Perks "Sip. Peel. Win Sweepstakes" login page asking for email/password. The REAL modern auth is on social-sso endpoints. | **New** — naming is misleading, "ssoprd" is legacy |
| A14 | OIDC discovery fully exposed on 4 endpoints (social-sso prd/preprod/stg + ssostg). Reveals full OAuth2 capability map including PAR, device auth, token exchange, DPoP. Spring Authorization Server. | **New** — complete auth architecture readable from public discovery docs |
| A15 | swagger.ddmdev.dunkindonuts.com resolves to bare AWS IP 34.237.71.65 with NO CDN protection. Potentially exposes full mobile API specification. | **New** — highest-value unprobed target |
| A16 | fps AND rbos both dead on same `caas-prod-dunkinbrands-com-261297133` ELB. All ports closed. CAAS platform fully decommissioned. | **Confirmed** — two dead services, one dead platform |
| A17 | UAT at 216.255.76.18 on IBM Cloud Managed App Services (Verizon Business / DIGEX-BLK-2 network). Completely unresponsive. No TLS cert. Different network from every other Dunkin' service. | **New** — legacy managed hosting, possibly pre-AWS migration |
| A18 | social-sso endpoints serve OIDC discovery (200) but block ALL other paths (403). JSESSIONID cookies set on 403 responses — Java backend. 403 regardless of User-Agent (mobile/desktop/curl). | **New** — WAF or app-level allow-list, not Akamai blocking |
| A19 | menu-pricing API returns 401 on EVERY path (actuator, swagger, api, root) — Spring Boot security catches everything before routing. Error JSON includes timestamps but no version/stack info. | **New** — well-secured API, uniform 401 |
| A20 | Vanity domain cert (CN: dunkinrun.com) covers `clubdunkin.com` and `*.dunkindonuts.co.uk` — previously unknown domains. Separate cert covers `*.dnkn.com` and `*.lsmnow.com`. | **New** — cert SANs reveal undiscovered domains |
| A21 | dev2/qa/qa2/staging3 error pages leak Apache server signature with hostname and port (`Apache Server at qa.dunkindonuts.com Port 80`). QA on port 80 confirms no TLS termination by CDN. | **New** — minor info leak via default Apache error pages |

## Resolved Questions

- [x] **What deep linking vendor?** → Branch.io (`dunkin.smart.link/f6iexb4x5`)
- [x] **What CDN?** → Akamai (ddmprod: `e36726.dsca.akamaiedge.net`, www: `e5079.a.akamaiedge.net`)
- [x] **Reddit targeting method?** → Interest-based (`utm_content=interests`, `utm_medium=paidsocial`)
- [x] **What is ddmprod?** → "Dunkin' Donuts Mobile Production" — custom in-house mobile platform, NOT a third-party product
- [x] **Is gibberish encoded?** → No. Crafted ad copy. 77% home-row keys, embedded family words.
- [x] **Do Inspire Brands sister brands use ddmprod?** → No. ddmprod is unique to Dunkin'. Each brand has completely different infrastructure.

## Open Questions

- [ ] What is `swi` in the ddmprod platform? LIVE in prod + all ddmdev envs (dev, dlt-dev, dlt-qa, qa). Not deprecated. Prod returns 404 (no default route). Purpose unknown.
- [ ] What is category 119 specifically? (All categories 100-130 return 302 — wildcard routing)
- [ ] What specific Reddit interest categories triggered this ad?
- [x] **What is `fps.dunkinbrands.com`?** → DEAD. Shares `caas-prod-dunkinbrands-com-261297133` ELB with rbos. CAAS platform fully decommissioned. All ports closed.
- [x] **What is RBOS?** → DEAD. "Restaurant Business Operating System" — same CAAS ELB as fps. Both decommissioned.
- [x] **What is the Genesis platform?** → DEAD. Both `genesisproduction.dunkinbrands.com` and `genesissandbox.dunkinbrands.com` return NXDOMAIN. Fully decommissioned. Purpose unknown but naming suggests an internal business platform.
- [ ] What is `star.dunkinbrands.com`? GET returns 200 (body not captured), HEAD returns 405, Allow: GET only. Behind Akamai e5079. Has staging variant `star-stg`. All non-root paths 404.
- [ ] Who is Terry Ursino? (Email leaked in CT logs)
- [ ] What is swagger.ddmdev.dunkindonuts.com serving? Bare AWS 34.237.71.65, no CDN. Potentially live Swagger UI.
- [ ] What are `dnkn.com` and `lsmnow.com`? Found on dunkinnation/brglobalfranchising TLS cert SANs.
- [ ] What is `clubdunkin.com`? Found on vanity domain cert SANs alongside dunkinrun.com.
- [ ] Why does QA use a completely different TLS cert (Amazon RSA wildcard) with `*.awsprd`/`*.awsstg`/`*.awspt` SANs?
- [ ] What is the star service GET response body? Only status codes captured in Wave 2.

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
| results.txt | `artifacts/ct-log-deep-dive-2026-04-13/` | CT log enumeration: 1091 certs, 136 unique subdomains, ~76 live (probe 11) |
| results.txt | `artifacts/legacy-services-2026-04-13/` | Legacy dunkinbrands.com probing: star, fps, rbos, genesis, franchiseecentral (probe 12, partial — died at fps port scan) |
| results.txt | `artifacts/qa-dev-environments-2026-04-13/` | QA/dev/staging environment comparison: headers, error pages, certs, whois (probe 13) |
| results.txt | `artifacts/menu-pricing-api-2026-04-13/` | Menu pricing API: Spring Boot actuator sweep, Swagger discovery, content-type probing (probe 14) |
| results.txt | `artifacts/loyalty-sso-2026-04-13/` | SSO/loyalty probing: OIDC discovery, Spring Auth Server, DD Perks login (probe 15, partial — died at dead loyalty DNS) |
| results.txt | `artifacts/wayback-deep-dive-2026-04-13/` | Wayback CDX queries: mostly timed out due to rate limiting (probe 16, minimal) |
| results.txt | `artifacts/vanity-domains-2026-04-13/` | Vanity domain mapping: DNS, redirect chains, TLS certs for 10 domains (probe 17) |
