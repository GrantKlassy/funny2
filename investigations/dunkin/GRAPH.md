# Dunkin' Ad Infrastructure Investigation

> Started: 2026-04-13
> Status: Active — Wave 5 complete (51 scripts, 49 artifacts)
> Last probed: 2026-04-14T07:33Z

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
| E19 | service | `swi.prod.ddmprod.dunkindonuts.com` | Unknown service ("SWI"). LIVE in prod, preprod, dev, qa (all 404 on 35 paths). dlt-dev/dlt-qa return 503 (taken down). Rails backend confirmed (X-Runtime, X-Request-Id, Status header). Shares cert with mapi-dun, ode, ulink. 6 environments, actively maintained, purpose completely unknown. |
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
| E33 | service | `star.dunkinbrands.com` | **IDENTIFIED**: Restaurant Administration Portal (RAP). Full login page exposed (18447 bytes). CrunchTime integration — login form has Username, Password, EntityID (4-digit CrunchTime store ID). ASP.NET Core backend. POST to `/User/LogInCrunchTime`. Google reCAPTCHA, jQuery 3.5.1, Poppins font, Akamai mPulse RUM (key: GFCZV-BTVLG-LZNSL-B55G9-NWDGT). Also has OTP email login flow (`/User/GenrateOTPForUser` — note the typo "Genrate"). Staging: `star-stg.dunkinbrands.com`. Behind Akamai e5079. |
| E34 | mobile-app | Dunkin' (Android) | Package: `com.cardfree.android.dunkindonuts`. Built by CardFree. Environments: DEV, UAT, prod. Single signing key (SHA256: CE:A1:...:D8:64). Android Asset Links on ulink.prod.ddmprod. |
| E35 | portal | `franchising.inspirebrands.com` | Centralized Inspire Brands franchising portal. Both `dunkinfranchising.com` and `baskinrobbinsfranchising.com` redirect here. Cloudflare hosted. |
| E36 | domain | `baskinrobbins.com` | Sister brand domain. Shares A records (52.0.33.13, 35.169.92.22), AWS Route 53, AND the www TLS cert (47 SANs) with dunkindonuts.com. Literally the same infrastructure. |
| E37 | service | `fps.dunkinbrands.com` | DEAD. Shares CNAME with rbos.dunkinbrands.com → same ELB: `caas-prod-dunkinbrands-com-261297133.us-east-1.elb.amazonaws.com`. CAAS platform decommissioned. All ports closed. |
| E38 | ct-exposure | dunkinbrands.com CT logs | 931 cert entries exposing: Citrix, VPN (SSL/web/password), VDI, Xen, IBM collab (QuickPlace/Quickr/iNotes), Genesis platform, SmartSolve EQMS, PLM, RBOS, POSHC, STS, 3 smartphone mgmt endpoints. Email leak: terry.ursino@dunkinbrands.com in cert CN. |
| E39 | vendor | Cloudflare | CDN for franchisee portal, franchising redirects, dunkinfranchising.com, baskinrobbinsfranchising.com. |
| E40 | platform | `ddmdev` | "Dunkin' Donuts Mobile Development" — separate dev platform from ddmprod. Sub-environments: dev, dlt-dev, dlt-qa, qa. Has its own Akamai edgekey configs. Services mirror ddmprod: ulink, mapi-dun, ode, swi. |
| E41 | service | `swagger.ddmdev.dunkindonuts.com` | **IDENTIFIED**: Swagger Editor (NOT Swagger UI/API docs). Nginx server. Last-modified: 2019-12-23 (6+ years). 3540 bytes. Only `/` returns 200, all API paths return 404. Bare AWS EC2 (34.237.71.65), no CDN. Wildcard cert `*.ddmdev.dunkindonuts.com`. A developer tool someone spun up in 2019 and forgot about. |
| E42 | service | `auth0-stg.dunkindonuts.com` | Auth0 staging. CNAME → AWS API Gateway (`d-7p5rilj85g.execute-api.us-east-1.amazonaws.com`). Suggests Auth0 was considered/used for authentication. |
| E43 | sso | Spring Authorization Server | Modern OAuth2/OIDC SSO. OIDC discovery exposed on social-sso (prd/preprod/stg) and ssostg. Supports: auth code, client credentials, refresh token, device auth, token exchange. PKCE (S256), DPoP, mTLS. |
| E44 | vendor | ServiceNow | Customer service platform. `chat.dunkindonuts.com` → `inspirecustomer.service-now.com`. Dev/test instances exist (`chatdev`→`inspirecustomerdev`, `chattest`→`inspirecustomertest`). |
| E45 | vendor | Paradox AI | AI-powered recruiting. `careers.dunkindonuts.com` → `careers-dunkindonuts-com.sites.paradox.ai`. |
| E46 | vendor | Adobe Analytics | Web analytics. `smetrics.dunkindonuts.com` → `dunkindonuts.com.102.122.2o7.net` (Omniture/Adobe). |
| E47 | vendor | Salesforce Marketing Cloud | Email marketing. `emailinfo.dunkindonuts.com` subdomains (click, cloud, image, view) → Salesforce SFMC content servers. |
| E48 | service | POS API cluster | Point of Sale APIs on AWS API Gateway. All return 403 Forbidden (`{"message":"Forbidden"}`). `pos-api`, `opc-api`, `dbapi` return 403 on all methods. `pos-ws`, `dbapi-ws` return 426 Upgrade Required on GET (WebSocket endpoints). `dbapi` also behind CloudFront. `ddapi` and `ddapi.staging` are DEAD (164.109.x IPs, no TLS). |
| E49 | service | `international.dunkindonuts.com` | International Dunkin' site. A: 20.74.242.116 — Azure (Microsoft), completely different cloud from all other Dunkin' infrastructure. |
| E50 | service | `thecenter.dunkinbrands.com` | **IDENTIFIED**: AEM (Adobe Experience Manager) franchisee learning portal. Cert: O=Inspire Brands, Inc., L=Sandy Springs (Inspire HQ). Apache + AEM dispatcher behind CloudFront. Content: "Dunkin Learning Path", bakery equipment training, spring readiness seasonal content. Okta login CSS. AEM admin login page (`/libs/granite/core/content/login.html`) returns 200 (12753 bytes). Security paths (crx/de, system/console, etc.) properly 404'd. Login background image and logo publicly accessible. |
| E51 | service | `recognition.dunkinbrands.com` | Employee recognition platform. CNAME → `dunkin-brands.werecognize.com` (WeRecognize). 302 redirect on access. |
| E52 | service | `rbos.dunkinbrands.com` | DEAD. Same CAAS ELB as fps (caas-prod-dunkinbrands-com). "Restaurant Business Operating System" — decommissioned with fps. |
| E53 | service | `flq-prod-idp.dunkinbrands.com` | Identity Provider. A: 74.199.217.23. GET returns 302 (redirect to login). Same subnet as smartsolve (74.199.217.x). |
| E54 | service | `login.dunkindonuts.com` | Login portal. A: 104.18.32.124 (Cloudflare). |
| E55 | service | `api-idp.dunkindonuts.com` | Identity Provider API. A: 104.18.32.226 (Cloudflare). |
| E56 | vendor | IBM Cloud Managed App Services | Hosts UAT environment. `uat.dunkindonuts.com` → 216.255.76.18 (Verizon Business / DIGEX-BLK-2 / IBM ICMAS network). UAT is completely unresponsive. |
| E57 | vendor | CrunchTime | Restaurant operations platform. Integrated at star.dunkinbrands.com (RAP). Login requires Username + Password + 4-digit EntityID. POST endpoint: `/User/LogInCrunchTime`. Success redirects to `/dashboard`. |
| E58 | service | `bam.dunkinbrands.com` | "BAM" — unknown purpose. 302 redirect to Okta SSO at `sso.inspirepartners.net/app/inspirepartners_bam_1/exk938s08y7yt4V9f697/sso/saml`. IIS 10.0, ASP.NET 4.0. Anti-XSRF tokens. Amazon RSA cert with SANs: `*.corporateportal.dunkinbrands.com`, `*.franchisee.dunkinbrands.com`. |
| E59 | vendor | Okta (Inspire Partners) | SSO at `sso.inspirepartners.net`. SAML integration for internal apps. App ID `inspirepartners_bam_1` for BAM. |
| E60 | service | `wsapi.dunkinbrands.com` | Web Service API. Returns 404 with Envoy proxy, `x-theorem-auth: nil`, `x-theorem-platform: nil`. TLS cert CN is `api-test.theoremlp.com` (Let's Encrypt, expires 2026-04-21) — **WRONG CERT**, Theorem LP's test cert serving on Dunkin's domain. |
| E61 | vendor | Theorem LP | Digital product consultancy. Their test API cert (`api-test.theoremlp.com`) is being served by wsapi.dunkinbrands.com. Likely a current or former development vendor. |
| E62 | service | `smartsolve.dunkinbrands.com` | SmartSolve EQMS. IP: 74.199.217.32. OPTIONS/PUT/DELETE return HTTP 200 on HTTPS. GET/POST fail (connection reset). HTTP GET returns 302. DigiCert wildcard cert `*.Dunkinbrands.com`. Same /24 subnet as flq-prod-idp. |
| E63 | service | `sts.dunkinbrands.com` | DEAD Security Token Service. CNAME: `stsprod.itdns.dunkinbrands.com` → 12.170.52.233 (AT&T network). TLS failed. All ADFS federation metadata paths return 000. Legacy ADFS from pre-cloud era. |
| E64 | service | `sslvpn.dunkinbrands.com` | DEAD SSL VPN. IP: 12.170.52.152 (AT&T network). Same AT&T /24 as STS. All connections 000. TLS failed. |
| E65 | service | `citrix.dunkinbrands.com` | DEAD Citrix Gateway. IP: 164.109.80.73. All connections 000. TLS failed. |
| E66 | brand | Arby's (`arbys.com`) | Inspire Brands sister. Cloudflare DNS+CDN. SendGrid DKIM (s1/s2). M365 DKIM (inspirebrands.onmicrosoft.com). Same Proofpoint MX (mxa/mxb-00919702). 110 CT subdomains. Ordering: Cloudflare direct. KnowBe4 phishing training. |
| E67 | brand | Buffalo Wild Wings (`buffalowildwings.com`) | Inspire Brands sister. CSC DNS, Cloudflare CDN. SendGrid DKIM (s1/s2). M365 DKIM. Same Proofpoint MX. Firebase: `buffalo-united`. Cisco CI. No `order.` subdomain. |
| E68 | brand | Sonic Drive-In (`sonicdrivein.com`) | Inspire Brands sister. CSC DNS, Cloudflare CDN. SendGrid+Mailchimp/Mandrill+M365 DKIM. Same Proofpoint MX. 281 CT subdomains. Auth0 verification present. Dynatrace APM. Atlassian. **DNS TXT includes chat message pasted with metadata**: `"[6:20 PM] Nelson, Brandi     atlassian-domain-verification=..."` |
| E69 | brand | Jimmy John's (`jimmyjohns.com`) | Inspire Brands sister. Cloudflare DNS. SendGrid+M365 DKIM. Same Proofpoint MX. 86 CT subdomains. Mailgun for email. No `order.` subdomain. Docker + Portainer exposed in CT logs (dev-portainer, docker). |
| E70 | domain | `clubdunkin.com` | Defunct loyalty program domain. Redirects → `www.dunkindonuts.com/en/clubdunkin`. Created 2020-09-03. CSC Corporate Domains. On vanity cert (CN: dunkinrun.com). |
| E71 | domain | `dnkn.com` | Short redirect domain. **EXPIRED cert** (expired 2022-09-28, CN: brglobalfranchising.com). Still resolves. Redirects → dunkindonuts.com. Created 2003-12-20. Cert SANs: `*.dnkn.com`, `*.lsmnow.com`, catering.dunkindonuts.com, dunkinnation.com, staging.dunkinfranchising.com. |
| E72 | domain | `lsmnow.com` | Local Store Marketing portal. Redirects to `lsm-prod-idp.dunkinbrands.com/my.policy` (F5 BIG-IP access policy). MX: mail.flairpromo.com (promotional marketing vendor). Created 2004-02-05. Same expired cert as dnkn.com. |
| E73 | domain | `dunkinnation.com` | Redirect loop. Root → 301 → `https://www.dunkinnation.com/` → 000 (dead). The www subdomain is dead but root keeps redirecting to it forever. On www cert SANs (staging.dunkinnation.com, staging3.dunkinnation.com also listed). |
| E74 | service | `news.dunkindonuts.com` | Brand newsroom. CNAME → `news.dunkindonuts.com.iprsoftware.com` (IPR Software). AMP version at `amp.news.dunkindonuts.com` → `amp.dunkin.iprsoftware.com` (GCP). |
| E75 | vendor | Movable Ink (`mi.dunkindonuts.com`) | **IDENTIFIED**: Email personalization/tracking platform, NOT "Marketing Intelligence." CNAME → `d187xgimezr5cv.cloudfront.net` (CloudFront). Serves 79-byte HTML: `<title>Movable Ink Domain</title>` with empty body. Own Amazon RSA cert (CN: mi.dunkindonuts.com). All paths except `/` return 404. Wayback: active since 2021. |
| E76 | vendor | SendGrid | Transactional email for Arby's (u34483924), BWW (u30126554), Sonic (u29175196), Jimmy John's (u57117). Different account per brand. DKIM selectors s1/s2. |
| E77 | vendor | KnowBe4 | Security awareness/phishing training. Domain verification present on arbys.com, buffalowildwings.com, sonicdrivein.com. Same verification token across all three brands. |
| E78 | vendor | Delivery Agent (dead) | E-commerce/merchandise fulfillment. `secureshop.dunkindonuts.com` → CNAME → `secureshop-dunkindonuts.st.deliveryagent.com` (connection refused). deliveryagent.com still registered (Namecheap, SiteGround hosting, created 2000). Wayback shows live Dunkin' shop with cart.php, account.php until 2019 (then 503s). |
| E79 | domain | `dunkindonuts.co.uk` | UK domain. Registered 15 March 2004, expires 15 March 2027. **Last updated 11 March 2026** (still actively maintained). Redirects → `https://dunkin.co.uk:443/` (rebranded UK domain). Same AWS ALB pool (35.153.79.184, 35.173.143.243). SPF still configured with Proofpoint. Google site verification present. On vanity cert (CN: dunkinrun.com). All subdomains NXDOMAIN. Wayback: served real content 2004-2015. |
| E80 | domain | `dunkinemail.com` | Email signup domain. **5-hop redirect chain through 3 loyalty program eras**: dunkinemail.com → www.dunkinemail.com (ELB) → `/content/dunkindonuts/en/responsive/dunkin_email.html` (Akamai, legacy CMS path) → `/en/dd-perks/registration` (DD Perks era) → `/en/dunkinrewards/registration` (Dunkin' Rewards era) → **403 Forbidden**. You cannot sign up for email via the email domain. |
| E81 | domain | `ddperks.com` | Legacy loyalty domain. Redirect chain: ddperks.com → www.ddperks.com (ELB) → `/en/dd-perks` → `/en/dunkinrewards` → 200. Works, unlike dunkinemail. Wayback: redirecting since 2009. |
| E82 | domain | `dunkinperks.com` | Transitional loyalty domain. **4 brand layers**: dunkinperks.com → www (Akamai) → `/content/dunkindonuts/en/responsive/ddperks/splashpage.html` (oldest CMS path) → `/en/dd-perks` → `/en/dunkinrewards` → 200. The deepest archaeological dig. |
| E83 | domain | `dunkinrewards.com` | Current loyalty domain. Shortest chain: dunkinrewards.com → www (Akamai) → `/en/dunkinrewards` → 200. Own cert (CN: dunkinrewards.com, issued Mar 2026). |
| E84 | firebase | BWW Firebase `buffalo-united` | **Firebase project exists but never built.** Hosting serves the DEFAULT "Welcome to Firebase Hosting Setup Complete" page (SDK 7.22.0, circa 2020). Database returns 401 (auth required — exists but locked). `/__/firebase/init.js` exposes full config: apiKey `AIzaSyCmtykcZ6UTfD0vvJ05IpUVe94uIaUQdZ4`, projectId `buffalo-united`, measurementId `G-VNQ194T6TN`, storageBucket `buffalo-united.appspot.com`. The page literally says "Now it's time to go build something extraordinary!" — they never did. |
| E85 | service | `franchisee.dunkinbrands.com` | **LIVE franchisee portal**. Root redirects 301 → `/DunkinPortal/` (ASP.NET path). Cloudflare CDN + AWSALB backend. Test env: `test.franchisee.dunkinbrands.com` (3 AWS IPs). Prod env: `prod.franchisee.dunkinbrands.com` (2 AWS IPs). Distinct from `franchiseecentral.dunkinbrands.com` (E29, last-modified 2016). Wayback: active since 2015. |
| E86 | service | WebSocket POS (`pos-ws`, `dbapi-ws`) | WebSocket endpoints on AWS API Gateway. GET → 426 Upgrade Required (`sec-websocket-version: 13`). WebSocket upgrade → 403 Forbidden (`{"message":"Forbidden"}`). All subprotocols, paths, and Origin headers return 403. Each has dedicated cert. Different API Gateway IDs: `d-9qf2wa4mt6` (pos-ws), `d-jd10dqc4l6` (dbapi-ws). Properly secured. |
| E87 | brand-infra | Jimmy John's DevOps (CT log exposure) | CT logs reveal internal DevOps infrastructure: `dev-portainer` and `docker` (NXDOMAIN — cleaned up), `bitbucket` (resolves but 000), `jira` → `jimmyjohns.atlassian.net` (migrated to cloud), `hipchat` (NXDOMAIN), `tableau` (NXDOMAIN), `intranet` → `services.jimmyjohns.com/pages/aspx/dashboard/`. Also: `WSUS` (104.129.153.139, LIVE), `rodc` (Read-Only Domain Controller, 104.129.153.144, LIVE), `vpn` (LIVE), `jj-fortiems` (FortiEMS, LIVE), `remotesupport` → `jjf.bomgarcloud.com` (BeyondTrust). **`guest.jimmyjohns.com` → 192.168.7.250** (RFC 1918 private IP in public DNS!). |
| E88 | brand-infra | Sonic Drive-In subdomain archaeology | **228 live subdomains** out of 271 CT-logged (84% alive). Infrastructure fossils: `fydibohf25spdlt` (Exchange Server legacyExchangeDN system attribute — Microsoft's internal identifier for `/o=First Organization`, should NEVER appear in public DNS), `callpilot7` (Nortel CallPilot voicemail — Nortel bankrupt 2009), `nokia` (Nokia network equipment), `vdr-2016`/`vdr-2018`/`vdr-2019` (Virtual Data Rooms — M&A due diligence from the Inspire Brands acquisition, year-stamped), `badweather` (weather tracking for a drive-in chain), `totzone`, `sonicfacebook`, `matchmaker`/`matchmaker-new`, `drawings`. Five VPN endpoints on `.digital` TLD domains (`sonicdrivein.digital`, `sonicdrivein-nonprod.digital`, `sonicdrivein-sandbox.digital`). Four firewall subdomains in public DNS (firewall, firewall1, firewall2, firewall95). `checkmarx` (Checkmarx code security). `b2bftp` (HTTP 200). Most hosts on 12.41.206.0/24 on-prem range. HTTP sweep timed out mid-alphabet — deep probes pending. |

| E89 | vendor | Bynder DAM (`thevault.inspirebrands.com`) | **Digital Asset Management for all Inspire brands.** Cert CN: `inspirebrands.bynder.com`. Login page title: "Inspire Brands Portal". CSP leaks: `dam.bynder.com`, `apiv2.webdamdb.com/oauth2/token` (WebDAM API), Sentry DSN `638cfd1ab10c78c179140416b9893c0e`, Amplitude analytics, Appcues onboarding, Osano consent. Cookie: `bynder=FA4D3B16-D2EB-4830-BDACFAA0ABAC3C34`. All brand images served via `thevault.inspirebrands.com/transform/{guid}/` URLs. |
| E90 | tenant | Inspire M365 Tenant `2f611596-a3da-4a81-94e8-fd4483868fc1` | **Single M365 tenant for all 8 brands.** Tenant name: `inspirebrands.onmicrosoft.com`. All DKIM selectors route through this tenant. Federated via Okta: inspirebrands.com, sonicdrivein.com, jimmyjohns.com (each has different Okta app ID). Managed (cloud-only): dunkinbrands.com, arbys.com, buffalowildwings.com, baskinrobbins.com. Not enrolled: dunkindonuts.com, lsmnow.com, dunkinnation.com. |
| E91 | vendor | inspire.okta.com (Employee SSO) | **Employee Okta org** for M365 federation. Three separate app IDs per brand: `exk1tue64p6nCY9BV2p7` (inspirebrands), `exk50lfvv21Ks2cBe2p7` (sonicdrivein), `exk7hrs0c7hQwroHg2p7` (jimmyjohns). Same signing certificate across all three. OIDC discovery fully exposed. |
| E92 | vendor | sso.inspirepartners.net (Partner/Franchisee SSO) | **Separate Okta org** for franchisee/partner apps. Backend: `inspirepartners.okta.com`. CSP reveals: `inspirepartners-admin.okta.com`, `inspirepartners.kerberos.okta.com`, `inspirepartners.mtls.okta.com`. BAM redirects here: `app/inspirepartners_bam_1/exk938s08y7yt4V9f697/sso/saml`. P3P header: **`CP="HONK"`**. Let's Encrypt cert (Mar 2026 - Jun 2026). |
| E93 | vendor | Sonic Freshdesk (`sonic.freshdesk.com`) | **Freshdesk support portal for Sonic.** Returns 302 → `/support/home` → requires login. API endpoints (tickets, agents) return 401. Behind Cloudflare + Freshworks infrastructure. Separate from Inspire Brands' ServiceNow instance — Sonic retained their own support platform post-acquisition. |
| E94 | service | `impact.inspirebrands.com` | **WordPress site on WP Engine** for ESG/Impact reporting. Site title: "Inspire Impact — Elevating Each Other & Our Communities". WP JSON API exposed (`/wp-json/`). User enumeration disabled. Let's Encrypt cert (R12, Mar-Jun 2026). |
| E95 | bucket | `baskin-robbins` GCS bucket | **PUBLICLY LISTABLE.** 34 objects, all from February 2019. Contents: `1080.png`, `intro0.jpg`-`intro2.jpg` (intro screens), `df/icecream/` (ice cream menu photos), `df/icecream/type/` (serving sizes — pint, "quater", family, half, single, etc.), `df/promo/` (card, discount, point, promo promotions), `menu/` (quiz images). **Contains typo: `02_quater.jpg`** ("quarter" misspelled). All EXIF metadata stripped. Appears to be assets from a 2019 Baskin-Robbins mobile app or campaign, abandoned in place. |
| E96 | vendor | PerimeterX (bot protection) | **Bot management across Dunkin' + Baskin-Robbins.** Different app IDs per brand: `PXt8Yg6FBv` (Dunkin'), `PXvTB0VdEc` (Baskin-Robbins). Challenge scripts served from `client.px-cloud.net`. Hardcoded in homepage HTML with collector endpoints at `collector-{appId}.px-cloud.net`. |
| E97 | vendor | Fiserv UCOM (payments) | **Payment processing for Dunkin' + Baskin-Robbins.** Brand-specific subdomains: `ucom-dnkn.fiservapis.com` (Dunkin'), `ucom-bskn.fiservapis.com` (Baskin-Robbins). SDK loaded from `/ucom/v2/static/v2/js/ucom-sdk.js`. |
| E98 | vendor | Radar.io (geolocation) | **Location services.** JS loaded from `js.radar.com/v4.5.3/radar.min.js` on Dunkin' homepage. Used for store locator functionality. |

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
| E33 | integrates | E57 | RAP login form POSTs to `/User/LogInCrunchTime` with CrunchTime credentials |
| E58 | auth-via | E59 | BAM redirects to `sso.inspirepartners.net` for SAML SSO (Okta) |
| E60 | wrong-cert | E61 | wsapi.dunkinbrands.com serves Theorem LP's test cert (`api-test.theoremlp.com`) |
| E62 | same-subnet | E53 | SmartSolve (74.199.217.32) and flq-prod-idp (74.199.217.23) — same managed hosting |
| E63 | same-network | E64 | STS (12.170.52.233) and SSLVPN (12.170.52.152) — both AT&T, pre-cloud era |
| E8 | parent-of | E66 | Inspire Brands → Arby's |
| E8 | parent-of | E67 | Inspire Brands → Buffalo Wild Wings |
| E8 | parent-of | E68 | Inspire Brands → Sonic Drive-In |
| E8 | parent-of | E69 | Inspire Brands → Jimmy John's |
| E66 | email-via | E13 | Same Proofpoint MX (mxa/mxb-00919702) as all Inspire brands |
| E67 | email-via | E13 | Same Proofpoint MX as all Inspire brands |
| E68 | email-via | E13 | Same Proofpoint MX as all Inspire brands |
| E69 | email-via | E13 | Same Proofpoint MX as all Inspire brands |
| E66 | dkim-via | E76 | SendGrid DKIM (s1/s2, account u34483924) |
| E67 | dkim-via | E76 | SendGrid DKIM (s1/s2, account u30126554) |
| E68 | dkim-via | E76 | SendGrid DKIM (s1/s2, account u29175196) |
| E69 | dkim-via | E76 | SendGrid DKIM (s1/s2, account u57117) |
| E50 | auth-via | E59 | The Center uses Okta login (CSS reference) |
| E72 | auth-via | — | lsmnow.com → lsm-prod-idp.dunkinbrands.com (F5 BIG-IP access policy) |
| E75 | tracks-for | E1 | mi.dunkindonuts.com serves Movable Ink email tracking pixel for Dunkin' campaigns |
| E78 | hosted-merch-for | E1 | secureshop.dunkindonuts.com → deliveryagent.com (dead PHP e-commerce, 2016-2019) |
| E79 | redirects-to | — | dunkindonuts.co.uk → dunkin.co.uk (post-rebrand UK domain) |
| E80 | rebrand-chain | E81, E82, E83 | dunkinemail.com → dd-perks/registration → dunkinrewards/registration → 403 |
| E82 | rebrand-chain | E81, E83 | dunkinperks.com → ddperks/splashpage → dd-perks → dunkinrewards → 200 |
| E84 | owned-by | E67 | BWW Firebase project (buffalo-united) |
| E85 | replaces | E29 | franchisee.dunkinbrands.com (/DunkinPortal/) likely successor to franchiseecentral (last-modified 2016) |
| E60 | infra-is | E61 | wsapi.dunkinbrands.com serves Theorem's Envoy proxy with x-theorem-auth/x-theorem-platform headers. Entire service IS Theorem's, not just the cert. |
| E61 | cert-expires | — | api-test.theoremlp.com cert expires 2026-04-21 (7 days from probe date). Same cert serving on wsapi.dunkinbrands.com. |
| E69 | devops-exposed | E87 | Jimmy John's CT logs: Portainer, Docker, Bitbucket, Jira, HipChat, Tableau, WSUS, RODC, FortiEMS, BeyondTrust |
| E69 | chat-via | E44 | chat.jimmyjohns.com → inspirecustomer.service-now.com (same ServiceNow instance as Dunkin') |
| E69 | careers-via | E45 | careers.jimmyjohns.com → careers-jimmyjohns-com.sites.paradox.ai (same Paradox AI as Dunkin') |
| E69 | ordering-via | E10 | online.jimmyjohns.com → whitelabel.olo.com (same OLO as Dunkin') |
| E88 | subsidiary-of | E8 | Sonic Drive-In acquired by Inspire Brands 2018. 228 live subdomains mapped. |
| E88 | subdomain-fossil | — | `fydibohf25spdlt` — Exchange legacyExchangeDN system attribute exported to public DNS |
| E88 | acquisition-artifact | — | `vdr-2016`, `vdr-2018`, `vdr-2019` — M&A Virtual Data Rooms still in DNS after 2018 acquisition |

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
- E33 (star) — **RAP: Restaurant Administration Portal** with CrunchTime login. Full login page exposed.
- E58 (bam) — redirects to Okta SSO at sso.inspirepartners.net (SAML). IIS 10.0, ASP.NET 4.0. Cert reveals `*.corporateportal.dunkinbrands.com`, `*.franchisee.dunkinbrands.com` SANs.
- E50 (thecenter) — AEM learning portal. Franchisee training: Dunkin Learning Path, bakery equipment, seasonal readiness. AEM admin login page accessible.
- E51 (recognition) — employee recognition via WeRecognize third-party
- E62 (smartsolve) — SmartSolve EQMS. OPTIONS/PUT/DELETE return 200. HTTP 302. 74.199.217.32.
- E53 (flq-prod-idp) — identity provider, 74.199.217.23 (same /24 as smartsolve)
- E60 (wsapi) — serves WRONG CERT from Theorem LP. Envoy proxy. 404.
- E29 (franchiseecentral) — Cloudflare + ASP.NET + AWSALB, last-modified 2016. Wayback: participation agreement PDF, FAST sales reports, DMB login.
- E37 (fps) + E52 (rbos) — dead CAAS platform. ELB name: `caas-prod-dunkinbrands-com-261297133`. All variants dead (caas, caas-dev, caas-staging, caas-stg, caas-qa, caas-uat, caas-preprod).
- Legacy AT&T infrastructure (all DEAD): E63 (sts, 12.170.52.233), E64 (sslvpn, 12.170.52.152), E65 (citrix, 164.109.80.73)

### CL12: SaaS Vendor Services
- E44 (ServiceNow) — customer chat (`inspirecustomer.service-now.com`), has dev + test instances
- E45 (Paradox AI) — recruiting/careers
- E46 (Adobe Analytics) — web analytics (Omniture/2o7.net)
- E47 (Salesforce Marketing Cloud) — email marketing (click/cloud/image/view subdomains)
- E57 (CrunchTime) — restaurant operations, integrated at RAP (star.dunkinbrands.com)
- E59 (Okta) — SSO at sso.inspirepartners.net for internal apps (BAM, The Center)
- E61 (Theorem LP) — digital consultancy, cert on wsapi.dunkinbrands.com
- E77 (KnowBe4) — phishing/security training (Arby's, BWW, Sonic — same verification token)
- All accessed via dunkindonuts.com or dunkinbrands.com CNAME aliases
- ServiceNow instance named "inspirecustomer" — Inspire Brands level, not Dunkin' specific

### CL13: Inspire Brands Email Infrastructure (cross-brand)
- ALL 7 brands (Dunkin', BR, Arby's, BWW, Sonic, JJ, Inspire) share identical Proofpoint MX: `mxa-00919702.gslb.pphosted.com` / `mxb-00919702.gslb.pphosted.com`
- Dunkin' uses legacy MX naming (psmtp.com), other brands use modern pphosted naming — same Proofpoint tenant
- ALL brands use identical SPF macro: `include:%{ir}.%{v}.%{d}.spf.has.pphosted.com`
- ALL brands use identical DMARC: `p=reject`, reporting to `dmarc_rua@emaildefense.proofpoint.com`
- ALL brands use M365 DKIM (selector1/selector2 → `inspirebrands.onmicrosoft.com`) — single tenant
- Arby's, BWW, Sonic, JJ also use SendGrid for transactional email (separate accounts per brand)
- Sonic additionally has Mailchimp/Mandrill DKIM (k1 → dkim.mcsv.net)
- JJ also uses Mailgun (`email.jimmyjohns.com` → mailgun.org)
- Salesforce Marketing Cloud: Dunkin', BWW, JJ, Inspire all have emailinfo subdomains (click/cloud/image)
- IPR Software: Dunkin' and BR both have `news.` subdomains for brand PR

### CL14: Ghost Domains & Redirect Graveyard
- E70 (clubdunkin.com) — defunct loyalty, redirects to dunkindonuts.com/en/clubdunkin
- E71 (dnkn.com) — **serving expired cert from 2022**. CN: brglobalfranchising.com. Still redirects.
- E72 (lsmnow.com) — Local Store Marketing. Redirects to F5 BIG-IP IDP. MX: mail.flairpromo.com. Created 2004.
- E73 (dunkinnation.com) — infinite redirect loop (root → www, www dead)
- catering.dunkindonuts.com — LIVE, 301 redirect
- shop.dunkindonuts.com — LIVE, 301 redirect
- secureshop.dunkindonuts.com — CNAME → deliveryagent.com (connection refused)
- international.dunkindonuts.com — LIVE on Azure (20.74.242.116), 200
- All ghost domains on AWS ALB pool (35.171.76.215, 44.218.38.45)
- Two cert groups: vanity pool (CN: dunkinrun.com) and franchising pool (CN: brglobalfranchising.com, EXPIRED)

### CL15: Sandbox Graveyard
- ALL sandbox endpoints are NXDOMAIN — entire sandbox environment decommissioned
- Dead: loyalty-api.sandbox, loyalty-mock-api.sandbox, rewards-api.sandbox, oats-api.sandbox, oats-ws.sandbox, splunkelb.sandbox, swagger.sandbox, ecselb.sandbox
- Wayback: oats-ws.sandbox returned 404 XML (2023), swagger.sandbox had robots.txt (2022)
- These were operational as recently as 2023 — full loyalty/rewards testing environment, now gone

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
| A22 | star.dunkinbrands.com exposes full RAP login page (18447 bytes) including CrunchTime login form with Username/Password/EntityID fields, CSRF tokens, OTP email flow, and Akamai mPulse RUM key. Function `GenrateOTPForUser` contains typo "Genrate" (not "Generate"). | **Confirmed** — full login page body captured |
| A23 | wsapi.dunkinbrands.com serves TLS cert for `api-test.theoremlp.com` (Let's Encrypt, Theorem LP). Dunkin's subdomain serving a completely different company's test certificate. Either cert misconfiguration or vendor handoff gone wrong. | **New** — wrong cert on Dunkin domain |
| A24 | SmartSolve (74.199.217.32) responds 200 to OPTIONS, PUT, and DELETE on HTTPS but connection-resets on GET/POST. HTTP GET returns 302. The 200 response is 247 bytes with `Cache-Control: no-cache` and `Content-Type: text/html`. Something is answering that shouldn't be. | **New** — partial service responding to unusual methods |
| A25 | ALL 7 Inspire Brands share identical email infrastructure: same Proofpoint tenant (MX, SPF macro, DMARC), same M365 tenant (inspirebrands.onmicrosoft.com), same SendGrid for transactional. One company operating 6 fast food chains' email through identical pipes. | **Confirmed** — complete email vendor consolidation |
| A26 | Sonic DNS TXT record contains a Slack/Teams chat message pasted with metadata: `"[6:20 PM] Nelson, Brandi     atlassian-domain-verification=ePV5FzMQ..."`. Someone copied the verification string from a chat message and pasted the ENTIRE message including timestamp and sender name into the DNS record. | **New** — chat metadata in DNS |
| A27 | KnowBe4 phishing training verification token is IDENTICAL across Arby's, BWW, and Sonic: `0c00dc3beaeabc5a1bb3e17db0f29f45`. Single KnowBe4 account for all brands. | **New** — shared security training |
| A28 | dnkn.com (created 2003) still serving an EXPIRED TLS cert from 2022 (CN: brglobalfranchising.com, expired Sep 28 2022). The cert has been expired for 3.5+ years but the domain still resolves and redirects. | **New** — multi-year expired cert in production |
| A29 | The Center (AEM portal) serves the Granite login page at `/libs/granite/core/content/login.html` (12753 bytes) — this is the AEM author instance login. Security-sensitive paths (crx/de, OSGi console, etc.) are properly blocked, but the login page itself is exposed. Dispatcher header: `dispatcher1useast1-06105218`. | **New** — AEM admin login page accessible |
| A30 | dunkinnation.com is stuck in an infinite redirect loop: HTTP root → 301 → HTTPS root → 301 → https://www.dunkinnation.com/ → connection refused. The www A record is dead but the root A record keeps trying to send people there. | **New** — broken redirect loop in production |
| A31 | All 8 sandbox endpoints (loyalty-api, loyalty-mock-api, rewards-api, oats-api, oats-ws, splunkelb, swagger, ecselb) return NXDOMAIN. Entire sandbox.dunkindonuts.com environment decommissioned. Wayback shows they were alive in 2022-2023. | **Confirmed** — sandbox fully decommissioned |
| A32 | SWI service: 35 paths probed across 6 live environments, ALL return 404 (or 503 on dlt-dev/dlt-qa). Rails backend (X-Runtime, X-Request-Id). Shares TLS cert with mapi-dun, ode, ulink. Actively maintained but purpose STILL completely unknown after exhaustive probing. | **Deepened** — remains the investigation's biggest mystery |
| A33 | bam.dunkinbrands.com cert reveals two undiscovered wildcard scopes: `*.corporateportal.dunkinbrands.com` and `*.franchisee.dunkinbrands.com` — suggesting tiered portal infrastructure. | **Probed** — corporateportal fully NXDOMAIN (12 certs but decommed), franchisee is LIVE with /DunkinPortal/ |
| A34 | mi.dunkindonuts.com is NOT "Marketing Intelligence" — it's **Movable Ink**, an email personalization vendor. Serves 79-byte HTML (`<title>Movable Ink Domain</title>`) with empty body on CloudFront. Own dedicated Amazon RSA cert. Vendor #30. | **Resolved** — Movable Ink tracking pixel domain |
| A35 | secureshop.dunkindonuts.com CNAME → `secureshop-dunkindonuts.st.deliveryagent.com`. Was a real e-commerce shop (cart.php, account.php) for Dunkin' merchandise until 2019. Delivery Agent (deliveryagent.com) still registered since 2000, still resolves (SiteGround hosting, 301 redirect), but the Dunkin shop is dead. DNS still points to the dead vendor. | **New** — fossilized vendor relationship |
| A36 | dunkindonuts.co.uk registered 2004, expires 2027, **last updated 11 March 2026**. Dunkin' exited the UK market but still actively maintains and renews this domain. Redirects to `dunkin.co.uk` (rebranded). SPF record still configured with Proofpoint. They're paying to maintain a domain for a market they left. | **New** — zombie domain maintenance |
| A37 | dunkinemail.com has a 5-hop redirect chain through 3 loyalty program eras: dunkinemail.com (ELB) → www.dunkinemail.com (Akamai) → `/content/.../responsive/dunkin_email.html` (legacy CMS) → `/en/dd-perks/registration` (DD Perks era) → `/en/dunkinrewards/registration` (Dunkin' Rewards era) → **403 Forbidden** "Access Denied." You cannot sign up for email via the email domain. | **New** — rebrand fossil chain ending on 403 |
| A38 | dunkinperks.com has the DEEPEST redirect chain: 4 brand layers. dunkinperks.com → Akamai → `/content/.../responsive/ddperks/splashpage.html` (oldest CMS path with "splashpage") → `/en/dd-perks` → `/en/dunkinrewards` → 200. The word "splashpage" in a URL path is a fossil from early-2010s web design. | **New** — 4-layer brand archaeology |
| A39 | BWW Firebase project "buffalo-united" has the DEFAULT "Welcome to Firebase Hosting Setup Complete" page still serving (SDK v7.22.0, circa 2020). Database exists (401 auth required). `/__/firebase/init.js` publicly exposes full Firebase config (API key, project ID, GA measurement ID, storage bucket). The page says "Now it's time to go build something extraordinary!" — they never did. A billion-dollar wing chain's abandoned Firebase project. | **New** — Firebase skeleton from 2020 |
| A40 | `franchisee.dunkinbrands.com` is LIVE with `/DunkinPortal/` path (ASP.NET). Has both `test.` and `prod.` subdomains on separate AWS IPs. Meanwhile `corporateportal.dunkinbrands.com` is fully NXDOMAIN despite 12 certs issued — the corporate portal was decommissioned but the franchisee portal survived. Feudal hierarchy in DNS. | **New** — franchisee portal alive, corporate dead |
| A41 | Theorem LP investigation: wsapi.dunkinbrands.com is NOT just serving Theorem's cert — the ENTIRE SERVICE is Theorem's Envoy proxy. `api-test.theoremlp.com` returns identical `x-theorem-auth: nil`, `x-theorem-platform: nil`, `server: envoy` headers. Dunkin's CNAME/A record points directly to Theorem LP's infrastructure. The api-test cert expires **2026-04-21** (7 days from probe date). | **Deepened** — entire service is Theorem's, not just cert |
| A42 | Jimmy John's CT logs reveal full DevOps stack: Docker/Portainer (cleaned up, NXDOMAIN), Bitbucket (dead but DNS remains), Jira → jimmyjohns.atlassian.net (migrated to cloud), HipChat/Tableau (NXDOMAIN), WSUS (LIVE at 104.129.153.139), RODC/Read-Only Domain Controller (LIVE). Most notable: **`guest.jimmyjohns.com` → 192.168.7.250** — a private RFC 1918 IP address in public DNS. Someone put their guest WiFi captive portal IP into the public DNS zone. | **New** — private IP in public DNS |
| A43 | WebSocket POS endpoints properly secured: pos-ws and dbapi-ws return 426 Upgrade Required on GET, but all WebSocket upgrade attempts (all subprotocols, all paths, all Origin headers) return 403 Forbidden via API Gateway. Each has dedicated cert and separate API Gateway ID. | **Resolved** — properly secured, no access |
| A44 | `fydibohf25spdlt.sonicdrivein.com` is a Microsoft Exchange Server `legacyExchangeDN` system attribute — the string is Exchange's internal identifier for `/o=First Organization`, famously garbled. It should NEVER be a public DNS subdomain. Someone exported Exchange's internal address book namespace directly into the public DNS zone. Resolves to 12.41.206.211 (same IP as their mail/OA server). | **New** — Exchange internals leaked to public DNS |
| A45 | Three Virtual Data Room subdomains year-stamped in DNS: `vdr-2016`, `vdr-2018`, `vdr-2019`. Sonic was acquired by Inspire Brands in late 2018 for $2.3B. These are the M&A due diligence data rooms from the acquisition timeline, with 2016 suggesting either an earlier approach or pre-deal prep. All still resolving on the 12.41.206.0/24 on-prem range, 7+ years later. | **New** — acquisition archaeology in DNS |
| A46 | Sonic has 228 live subdomains (84% of 271 CT-logged) including: Nortel CallPilot voicemail (`callpilot7`, Nortel bankrupt 2009), Nokia network equipment (`nokia`), weather tracking (`badweather` — existential threat for a drive-in chain), four publicly named firewalls (`firewall`, `firewall1`, `firewall2`, `firewall95` — why 95?), five VPN endpoints on separate `.digital` TLD domains, `drawings`, `totzone`, `sonicfacebook`, `matchmaker`/`matchmaker-new`. Enterprise archaeology spanning 20+ years of infrastructure on one /24 subnet. HTTP sweep timed out mid-alphabet. | **New** — 228-subdomain archaeology museum |

| A47 | `baskin-robbins` GCS bucket is **PUBLICLY LISTABLE**. 34 objects from February 2019 — ice cream menu photos, promo images, intro screens. No auth required. Accessible at `storage.googleapis.com/baskin-robbins/`. Contains file `02_quater.jpg` with "quarter" misspelled. All EXIF stripped. Appears to be a 2019 mobile app/campaign asset bucket left open. | **New** — public cloud storage, Wave 5 |
| A48 | **THE INSPIRE BRANDS TYPO COLLECTION**: (1) `GenrateOTPForUser` — Dunkin' RAP API (load-bearing). (2) `02_quater.jpg` — Baskin-Robbins GCS bucket ("quarter"). (3) `analitycSelectors/` — Dunkin' AEM filesystem path ("analytics", HTTP 200, 429 bytes). (4) `generatDataTestIds=false` — Shared Next.js platform meta tag on **Arby's, Sonic, AND Buffalo Wild Wings** ("generate"). One typo in a shared codebase, three restaurant chains. Jimmy John's does not have this meta tag (may be on older platform version). Four typos across the $30B parent company. | **New** — cross-brand typo epidemic, Wave 5 |
| A49 | `sso.inspirepartners.net` Okta SSO has P3P compact policy: `CP="HONK"`. That is the ENTIRE Platform for Privacy Preferences policy. Just "HONK." Someone set their privacy policy to a goose sound. The CSP header also leaks: `inspirepartners.okta.com`, `inspirepartners-admin.okta.com` (admin panel), `inspirepartners.kerberos.okta.com`, `inspirepartners.mtls.okta.com`, `oinmanager.okta.com`. | **New** — HONK, Wave 5 |
| A50 | Inspire Brands has **TWO separate Okta organizations**: `inspire.okta.com` (employee M365 federation, 3 brand-specific app IDs) and `inspirepartners.okta.com`/`sso.inspirepartners.net` (franchisee/partner apps like BAM). The partner org has a custom domain (`inspirepartners.net`) hiding the Okta org name. Both orgs share the same signing certificate. | **New** — dual Okta topology, Wave 5 |
| A51 | All 8 Inspire brands share a **single M365 tenant** (`2f611596-a3da-4a81-94e8-fd4483868fc1`). But 3 brands (Inspire, Sonic, JJ) are federated through Okta while 4 (Dunkin' Brands, Arby's, BWW, Baskin-Robbins) are managed directly. This split suggests incomplete identity migration — the acquired brands that had their own IT (Sonic 2018, JJ 2019) were federated rather than fully migrated. | **New** — partial M365 migration, Wave 5 |
| A52 | PerimeterX publishable API key `HB8XN-5GW29-UAXQ4-9XSZN-WM7MY` hardcoded in Dunkin' homepage HTML. Different PerimeterX app IDs per brand: `PXt8Yg6FBv` (Dunkin'), `PXvTB0VdEc` (Baskin-Robbins). | **New** — hardcoded key in HTML, Wave 5 |
| A53 | **10 S3 buckets confirmed to exist** (all return 403): dunkin, dunkindonuts, dunkin-assets, dunkin-menu, baskinrobbins, arbys, arby, bww, jimmyjohns, inspire-assets. Plus 3 GCS buckets: dunkin (403), dunkin-menu (403), baskin-robbins (**200 = public**). | **New** — bucket inventory, Wave 5 |
| A54 | SWI mystery **advances but not solved**: content-negotiates (returns `Content-Type: application/json` for JSON requests, `text/html` for HTML), generates unique `X-Request-Id` per request, has `X-N: S` header (Akamai marker), X-Runtime ~0.002s (hitting Rails routing, no controller). Still ALL 404 on every path including Rails-specific (`/rails/info/routes`, `/cable`, `/graphql`, `/up`, `/rails/health`), all HTTP methods (GET/POST/PUT/OPTIONS/HEAD), and all header permutations (XHR, Authorization). Active Rails API serving nothing publicly. | **Deepened** — Wave 5 |
| A55 | Theorem LP cert on `wsapi.dunkinbrands.com` still NOT renewed — expires **2026-04-21** (7 days from probe). Same cert on both `wsapi.dunkinbrands.com` and `api-test.theoremlp.com`. Let's Encrypt R13. If not auto-renewed, wsapi goes down or serves expired cert. | **Time-critical** — 7-day countdown, Wave 5 |
| A56 | Sonic's entire 12.41.206.0/24 on-prem subnet is **completely dark** to HTTP/HTTPS from the internet. All 13 IPs tested (211, 95, 234, 235, 10, 11, 69, 66, 30, 200, 100, 50, 1) return 000 on both ports 80 and 443. All SMTP/IMAP/POP3 ports also closed. Only port 53 (DNS) is open on WSUS and RODC hosts. 228 DNS subdomains pointing to firewalled infrastructure. | **New** — dark subnet, Wave 5 |
| A57 | `thevault.inspirebrands.com` is **Bynder** DAM (cert CN: `inspirebrands.bynder.com`). All Inspire brand images referenced in Arby's and Sonic HTML source use `thevault.inspirebrands.com/transform/{guid}/` URLs. Login page says "Inspire Brands Portal" with "Register a new account" option. CSP leaks Sentry DSN key, WebDAM API endpoint, and internal vendor stack. | **New** — DAM identified, Wave 5 |

## Resolved Questions

- [x] **What deep linking vendor?** → Branch.io (`dunkin.smart.link/f6iexb4x5`)
- [x] **What CDN?** → Akamai (ddmprod: `e36726.dsca.akamaiedge.net`, www: `e5079.a.akamaiedge.net`)
- [x] **Reddit targeting method?** → Interest-based (`utm_content=interests`, `utm_medium=paidsocial`)
- [x] **What is ddmprod?** → "Dunkin' Donuts Mobile Production" — custom in-house mobile platform, NOT a third-party product
- [x] **Is gibberish encoded?** → No. Crafted ad copy. 77% home-row keys, embedded family words.
- [x] **Do Inspire Brands sister brands use ddmprod?** → No. ddmprod is unique to Dunkin'. Each brand has completely different infrastructure.

## Open Questions

- [ ] What is `swi` in the ddmprod platform? 35 paths probed across 6 live environments — ALL 404. Rails backend confirmed. Remains completely unknown.
- [ ] What is category 119 specifically? (All categories 100-130 return 302 — wildcard routing)
- [ ] What specific Reddit interest categories triggered this ad?
- [x] **What is `fps.dunkinbrands.com`?** → DEAD. CAAS platform on `caas-prod-dunkinbrands-com-261297133` ELB. ALL CAAS variants dead (7 tested). Wayback: ASP.NET login.aspx.
- [x] **What is RBOS?** → DEAD. Same CAAS ELB as fps. Both decommissioned.
- [x] **What is the Genesis platform?** → DEAD. NXDOMAIN. Fully decommissioned.
- [x] **What is `star.dunkinbrands.com`?** → **Restaurant Administration Portal (RAP)**. Full CrunchTime login page captured. Username + Password + 4-digit EntityID. ASP.NET Core. OTP email flow. Success → `/dashboard`.
- [ ] Who is Terry Ursino? (Email leaked in CT logs — crt.sh still unreliable)
- [x] **What is swagger.ddmdev serving?** → Swagger Editor (not API docs). Nginx. Last-modified 2019-12-23. 3540 bytes. Only `/` works. A developer tool forgotten for 6+ years.
- [x] **What are `dnkn.com` and `lsmnow.com`?** → dnkn.com is short redirect domain with EXPIRED cert (3.5 years). lsmnow.com is Local Store Marketing portal behind F5 BIG-IP IDP with Flair Promo MX.
- [x] **What is `clubdunkin.com`?** → Defunct loyalty program redirect → dunkindonuts.com/en/clubdunkin. Created 2020.
- [ ] Why does QA use a completely different TLS cert (Amazon RSA wildcard) with `*.awsprd`/`*.awsstg`/`*.awspt` SANs?
- [x] **What is the star service GET response body?** → 18447-byte RAP login page with CrunchTime integration.
- [x] **What is BAM?** → Okta SAML-authenticated internal app. Root redirects to `sso.inspirepartners.net/app/inspirepartners_bam_1/exk938s08y7yt4V9f697/sso/saml`. On the partner/franchisee Okta org, not the employee org. Cert: `*.dunkinbrands.com` (Amazon RSA 2048, Feb-Sep 2026). All paths beyond root return 404. Likely "Brand Asset Management" or "Business Activity Management."
- [x] **What does Theorem LP do for Dunkin'?** → Theorem LP is a digital product consultancy (theoremlp.com, Netlify). wsapi.dunkinbrands.com is NOT just serving their cert — the entire service IS Theorem's Envoy proxy infrastructure. Both api-test.theoremlp.com and wsapi.dunkinbrands.com return identical `x-theorem-auth: nil`, `x-theorem-platform: nil` headers. The Let's Encrypt cert expires 2026-04-21.
- [x] **What are `*.corporateportal.dunkinbrands.com` and `*.franchisee.dunkinbrands.com`?** → corporateportal is fully NXDOMAIN (decommissioned, despite 12 certs issued). franchisee is LIVE: root → 301 → `/DunkinPortal/` (ASP.NET, Cloudflare + AWSALB). Has test and prod subdomains on AWS.
- [x] **What is `mi.dunkindonuts.com`?** → Movable Ink email personalization/tracking vendor. NOT "Marketing Intelligence." Serves 79-byte HTML placeholder on CloudFront.
- [ ] Who is Terry Ursino? (Wave 5: crt.sh returns empty JSON `[]` for all queries — direct name search, wildcard `%ursino%`, email search, identity search. Data may have aged out of CT log index, or the name was in a cert field not searchable via crt.sh. Mystery persists.)
- [ ] Will Theorem LP cert auto-renew before 2026-04-21? (Let's Encrypt certbot auto-renewal typically fires at 30 days before expiry, which was 2026-03-22 — if it didn't renew then, something is broken. Monitor daily.)
- [ ] What is the `baskin-robbins` GCS bucket? (2019 mobile app or campaign assets? Who uploaded them? Why is the bucket still public 7 years later?)
- [ ] What other apps are behind `sso.inspirepartners.net`? (We found BAM — `inspirepartners_bam_1` — are there `_bam_2`, or other app names?)
- [ ] Why does `generatDataTestIds` exist in 3 brands but not Jimmy John's? (JJ may be on older platform version, or has custom build config overriding the shared template.)

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
| results.txt | `artifacts/swagger-probe-2026-04-13/` | Swagger Editor on bare EC2: DNS, whois, TLS, HTTP path sweep, nmap (probe 18) |
| results.txt | `artifacts/swi-mystery-2026-04-13/` | SWI mystery: 7 environments, 35 paths each, Rails confirmed, all 404 (probe 19) |
| results.txt | `artifacts/mystery-services-deep-2026-04-13/` | RAP login page, k.prod Host trick, auth0-stg OIDC (probe 20) |
| results.txt | `artifacts/ghost-domains-2026-04-13/` | Ghost domains: clubdunkin, dnkn, lsmnow, dunkinnation, whois (probe 21) |
| results.txt | `artifacts/sister-brands-deep-2026-04-13/` | Sister brand DNS: NS/MX/TXT/DMARC/CAA/SOA/DKIM for 6 brands (probe 22) |
| results.txt | `artifacts/sister-brands-certs-2026-04-13/` | Sister brand certs, AASA, assetlinks, vendor detection (probe 23) |
| results.txt | `artifacts/sister-brands-ct-2026-04-13/` | CT logs: Arby's 110, Sonic 281, JJ 86 subdomains (probe 24) |
| results.txt | `artifacts/legacy-deep-2026-04-13/` | Legacy deep: smartsolve, bam, sts, wsapi, citrix, sslvpn (probe 25, partial) |
| results.txt | `artifacts/pos-api-cluster-2026-04-13/` | POS API cluster: all 403 on API Gateway, WebSocket 426 (probe 26) |
| results.txt | `artifacts/wayback-retry-2026-04-13/` | Wayback retries: franchiseecentral docs, fps login, sandbox history (probe 27) |
| results.txt | `artifacts/terry-ursino-2026-04-13/` | Terry Ursino cert search: all crt.sh queries 502 (probe 28) |
| results.txt | `artifacts/sandbox-loyalty-2026-04-13/` | Sandbox: all 8 endpoints NXDOMAIN, fully decommissioned (probe 29) |
| results.txt | `artifacts/email-infrastructure-2026-04-13/` | Email: cross-brand comparison, Salesforce MC, Proofpoint (probe 30) |
| results.txt | `artifacts/caas-archaeology-2026-04-13/` | CAAS: fps/rbos ELB, all variants dead, Wayback login (probe 32) |
| results.txt | `artifacts/thecenter-deep-2026-04-13/` | The Center: AEM paths, login page, Wayback learning content (probe 33) |
| results.txt | `artifacts/jimmy-portainer-2026-04-13/` | Jimmy John's DevOps: Portainer/Docker NXDOMAIN, Jira→Atlassian, guest→private IP, WSUS/RODC live (probe 34) |
| results.txt | `artifacts/rebrand-archaeology-2026-04-13/` | Loyalty rebrand chains: dunkinemail 5-hop→403, dunkinperks 4-layer, ddperks, dunkinrewards (probe 35) |
| results.txt | `artifacts/buffalo-firebase-2026-04-13/` | BWW Firebase: buffalo-united default page, RTDB 401, full config exposed (probe 36) |
| results.txt | `artifacts/portal-enumeration-2026-04-13/` | Portal wildcards: corporateportal NXDOMAIN, franchisee LIVE /DunkinPortal/, BAM paths (probe 37) |
| results.txt | `artifacts/marketing-intel-2026-04-13/` | Movable Ink identified, secureshop→deliveryagent dead, UK domain redirect (probe 38) |
| results.txt | `artifacts/websocket-handshake-2026-04-13/` | WebSocket POS: 426 confirmed, all upgrade attempts 403, properly secured (probe 39) |
| results.txt | `artifacts/sonic-sweep-2026-04-13/` | Sonic CT subdomain sweep: 228 live/43 dead DNS resolved, HTTP sweep partial (timed out mid-alphabet). Arby's section not reached. Key finds: fydibohf25spdlt (Exchange DN), VDR M&A rooms, 228 live subdomains (probe 40, partial) |
| results.txt | `artifacts/terry-theorem-2026-04-13/` | Terry retry (crt.sh still failing), Theorem LP: Envoy proxy, Netlify site, cert expires 4/21 (probe 41) |
| results.txt | `artifacts/smtp-banners-2026-04-14/` | SMTP/IMAP/POP3 banner grab: all ports closed on Sonic Exchange (.211, .95), Dunkin legacy (.23, .32), IBM UAT (.18), Proofpoint MX. Enterprise perimeter firewalling confirmed. (probe 42) |
| results.txt | `artifacts/m365-tenants-2026-04-14/` | M365 tenant discovery: single tenant 2f611596 across 8 brands. Federated (Okta): inspirebrands, sonic, JJ. Managed: dunkinbrands, arby's, BWW, BR. Not enrolled: dunkindonuts, lsmnow, dunkinnation. (probe 43) |
| results.txt | `artifacts/s3-gcs-buckets-2026-04-14/` | S3/GCS bucket enumeration: 10 S3 buckets exist (403), 3 GCS buckets found, `baskin-robbins` GCS is **publicly listable** with 34 objects. Contains typo `02_quater.jpg`. (probe 44) |
| results.txt | `artifacts/zendesk-probe-2026-04-14/` | Zendesk/Freshdesk/Intercom discovery: all 22 Zendesk subdomains return 403 (exist but restricted). `sonic.freshdesk.com` discovered (302, behind login). (probe 45) |
| results.txt | `artifacts/swagger-nmap-2026-04-14/` | Swagger EC2 deep scan: only port 443 open (out of 40+ tested). Fresh cert `*.ddmdev.dunkindonuts.com` (Feb 2026 - Mar 2027). No additional services found. (probe 46) |
| results.txt | `artifacts/js-bundles-2026-04-14/` | JS bundle analysis across 4 Inspire brand sites. Key finds: `analitycSelectors/` typo path, PerimeterX key hardcoded, `generatDataTestIds` typo on Arby's/Sonic/BWW, Bynder DAM URLs, Fiserv UCOM payments, Radar.io geolocation. (probe 47) |
| results-rerun.txt | `artifacts/exif-metadata-2026-04-14/` | EXIF on intake images: Reddit stripped most metadata, XMP Core 6.0.0 retained, dunkin3.jpg has Apple Display P3 ICC profile (Apple device screenshot). BR GCS images: all EXIF stripped. (probe 48) |
| results.txt | `artifacts/open-leads-2026-04-14/` | Open lead follow-ups: SWI content-negotiation confirmed but still all 404, Terry Ursino CT logs empty, Theorem cert unchanged (7-day countdown), BAM identified as Okta SAML app on inspirepartners.net. (probe 49) |
| results.txt | `artifacts/sonic-mail-deep-2026-04-14/` | Sonic on-prem dark (all 13 IPs 000), Inspire service probing: Bynder DAM cert/CSP, impact.inspirebrands WordPress/WPEngine, sso.inspirepartners.net Okta CP="HONK", Sonic Freshdesk behind login. (probe 50) |
| results.txt | `artifacts/jj-deep-2026-04-14/` | Jimmy John's deep: WSUS and RODC only have DNS (53) open, all other ports firewalled. FortiEMS, BeyondTrust, VPN all resolve but return nothing. (probe 51) |
