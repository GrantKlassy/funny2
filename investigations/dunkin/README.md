# I Reverse-Engineered Dunkin's Entire Mobile Infrastructure Because Their Reddit Ad Annoyed Me

## The Ad

I'm scrolling Reddit. It's late. I see this:

![dunkin ad 1](intake-2026-04-13/dunkin1.jpg)

Fine. A Dunkin' ad. I can ignore a Dunkin' ad. But then I see the *other* one:

![dunkin ad 2](intake-2026-04-13/dunkin2.jpg)

Read that text. Read it again. A corporate account — verified, promoted, paid money to put this in my feed — posted this:

```
Wjkhsgjkhdgkhkjfhgdfgdogihdgcatmomdfgddgjkk
kidogsyjkdffkkjkddadadadadadadadamommmmmmmdf
d7766Vvvqg8888
AAAAAAAAAaaaaaasssvIFFGHF7ghfh88
```

Followed by "Sorry, toddler had my phone."

No. No, your toddler did not have your phone. Your *copywriter* had your phone. And I can prove it.

## The Toddler Is a Lie

I ran the "gibberish" through keyboard distribution analysis. If a toddler actually mashed a keyboard, you'd expect roughly equal hits across all three rows — they don't know where the home row is. They're a toddler. They eat crayons.

Here's what the analysis found:

| Keyboard Row | Expected (toddler) | Actual |
|---|---|---|
| Top row (qwerty) | ~33% | **10%** |
| Home row (asdf) | ~33% | **77%** |
| Bottom row (zxcv) | ~33% | **12%** |

**Seventy-seven percent home row.** That's not a toddler. That's a grown adult resting their fingers on asdfghjkl and wiggling them around. The gibberish also contains strategically embedded words:

- `cat` (1x), `dog` (2x), `kid` (1x), `mom` (2x), `dad` (4x), `dada` (4x)

All family-and-pet themed. All placed to make you go "aww that's relatable" instead of "this is an ad." The last line — `mamamama dad dad dad momm mom mom mommm78499` — is so obviously written by a 28-year-old in a WeWork that it hurts.

It's a promoted post designed to look organic. The toddler is a psyop. Dunkin' is running narrative warfare on Reddit and the narrative is "I'm just like you, fellow parent."

## But Then I Clicked It

Against my better judgment, I tapped the ad. The URL was:

```
https://ulink.prod.ddmprod.dunkindonuts.com/dunkin/orders/category/119
```

And I landed here:

![landing page](intake-2026-04-13/dunkin3.jpg)

Wait. `ulink.prod.ddmprod.dunkindonuts.com`? That's not a normal marketing URL. That's a subdomain four levels deep with what looks like internal environment naming. `prod.ddmprod`? Production inside... another production? What is `ddmprod`?

So I did what any reasonable person would do. I opened a container and started running dig.

## What Is ddmprod?

**ddmprod** stands for **Dunkin' Donuts Mobile Production.** It's their entire internal mobile app platform. The name predates their 2018 rebrand from "Dunkin' Donuts" to just "Dunkin'" — the infrastructure team apparently didn't get the memo. Or didn't care. Either way, the ghost of "Donuts" lives on in their DNS.

Here's the thing about TLS certificates — they have to list every domain they cover. The cert on `ulink.prod.ddmprod.dunkindonuts.com` has a Subject Alternative Names list that reads like someone left the architecture diagram on a public bus:

| Service | What It Does |
|---------|-------------|
| `mapi-dun` | **Mobile API** — the actual app backend. This is the primary CN on the cert. `ulink` is just riding along. |
| `ulink` | **Universal Links** — the thing I clicked. Routes you to the app or the web depending on your device. |
| `ode` | **Order Delivery Engine** — exactly what it sounds like |
| `swi` | Nobody knows. LIVE in prod AND across all dev environments (dev, dlt-dev, dlt-qa, qa). Actively maintained. Prod returns 404 — no default route, not dead. We'll find out. |
| `dun-assets` | Static asset CDN. Serves `dunkin_logo@2x.png` to the app. |
| `cloud` | Only seen in preprod via Wayback. Mysterious. |

All of these exist in both `prod` and `preprod` environments. The whole thing runs on **Akamai CDN** with **DigiCert ECC certificates** issued to **Dunkin' Brands, Inc., Canton, Massachusetts.**

I mapped 56 entities from one drink ad. I know more about Dunkin's mobile backend than most of their employees.

## The Three-Way Split

The `ulink` service is a Node.js/Express app that sniffs your User-Agent and makes a decision:

**If you're on an iPhone with the app installed:** iOS Universal Links kick in. The app opens directly to `dunkin://orders/category/119`. You never see a webpage. You're just suddenly looking at drinks.

**If you're on a phone without the app:** You get the interstitial page (the "GET THE APP" screen I screenshotted). The "Continue on App" button is the good part — it links to:

```
https://dunkin.smart.link/f6iexb4x5?destination=dunkin://orders/category/119
```

`dunkin.smart.link` — that's **Branch.io**, the deep linking vendor. They're the ones who make sure that if you install the app from the App Store, you still land on the right category page. Deferred deep linking. It's actually kind of clever, if you ignore everything else about this situation.

**If you're on a desktop or you're a bot:** HTTP 302 redirect to `www.dunkindonuts.com/en/mobile-app`. Go away, you're not buying a drink from your laptop.

## The Vendor Stack (a.k.a. How Many Companies Does It Take to Sell a Mango Drink)

| Vendor | Role | How I Found It |
|--------|------|----------------|
| **Branch.io** | Deep linking | `dunkin.smart.link` in the landing page HTML |
| **OLO** | Online ordering | `order.dunkindonuts.com` CNAMEs to `whitelabel.olo.com` |
| **CardFree** | Mobile payments / gift cards | Listed in the Apple App Site Association file as `com.cardfree.ddnationalprd` |
| **Akamai** | CDN | CNAME chain: `edgekey.net` → `akamaiedge.net` |
| **Proofpoint** | Email security | MX records, SPF, DMARC. Policy is `p=reject` — at least their email security is tight |
| **DigiCert** | TLS certificates for mobile | ECC SHA384 certs for the ddmprod platform |
| **AWS** | Everything else | Route 53 DNS, Application Load Balancer, ACM certs for the root domain |

Seven vendors to sell you a zero-calorie tropical mango beverage. The `order.dunkindonuts.com` → `whitelabel.olo.com` CNAME was my favorite find. OLO is a restaurant ordering platform. The word "whitelabel" is right there in the DNS. It's like leaving the price tag on a gift.

## Why Was This Ad Targeted at Me?

The Wayback Machine answered this one. Historical snapshots of the `ulink` URLs preserved the full UTM parameters from previous campaigns:

```
utm_source=reddit
utm_medium=paidsocial
utm_campaign=dunkinrun
utm_content=interests
```

The targeting parameter is literally called `interests`. Reddit served me this ad because of my subreddit engagement patterns. Dunkin' paid Reddit to show me a fake toddler post based on an algorithmic guess about what I might enjoy.

Conversion tracking uses Reddit Click IDs (`rdt_cid` parameters) — unique identifiers appended to every ad click URL so Dunkin' can trace the journey from "saw ad on Reddit" to "ordered a drink in the app." There are at least 8 distinct `rdt_cid` values captured in Wayback from different campaign runs. Previous campaigns targeted categories 28, 53, and 70. Mine was 119.

## Bonus Round: The www Certificate

I checked the TLS cert on `www.dunkindonuts.com` for good measure. It lists **47 Subject Alternative Names.** Forty-seven. Including:

- `dev2.dunkindonuts.com`, `qa.dunkindonuts.com`, `qa2.dunkindonuts.com`, `staging.dunkindonuts.com`, `staging3.dunkindonuts.com`, `uat.dunkindonuts.com` — their entire development lifecycle is in this cert
- `ssoprd.dunkindonuts.com`, `social-ssoprd.dunkindonuts.com` — SSO infrastructure
- `menu-pricing-prd.dunkindonuts.com` — the menu pricing API, in production
- `franchiseecentral.dunkinbrands.com` — the franchisee portal
- `www.baskinrobbins.com`, `staging.baskinrobbins.com`, `qa.baskinrobbins.com` — Baskin-Robbins shares the cert

Nothing is exposed or exploitable. But the fact that you can learn the names of all their internal environments from a single `openssl s_client` command is... very Dunkin'.

## The u/dunkin Reddit Account

Created **October 18, 2018** — right when Dunkin' dropped "Donuts" from the name. The account was born with the rebrand. It has 62 link karma and 67 comment karma after 7+ years. The promoted posts don't appear in Reddit's public API because they're served through the ad system, not the user's post history. It's a ghost account that only exists to run paid campaigns.

It is verified. It is a moderator. It has almost no karma. It pretends a toddler typed on its phone to sell you a drink. It is `u/dunkin`.

## Wave 2: I Kept Going

At this point a normal person would have closed the terminal, touched grass, maybe ordered a Dunkin' drink ironically. I ran 7 more containerized probe scripts and discovered 34 additional entities. The investigation now has 56 nodes, 12 clusters, and 21 anomalies. Over a Reddit ad for a mango drink.

### CardFree Builds the Entire App

Remember how I said CardFree handled "mobile payments / gift cards"? I was being generous. The Android Asset Links file on `ulink.prod.ddmprod` lists the app package as `com.cardfree.android.dunkindonuts`. The iOS app's entitlements are under `com.cardfree.ddnationalprd`. The signing key is the same across DEV, UAT, and production builds.

CardFree doesn't just do payments. CardFree IS the app. The Dunkin' app is a CardFree product with Dunkin' branding. The in-app purchases, the ordering flow, the reward scanning — all CardFree. Every time you tap "Order Ahead" you're interacting with a company you've never heard of. Dunkin' is a CardFree customer wearing a costume.

### The Three Generations of Login

I probed every SSO endpoint on `dunkindonuts.com` and found three entirely different authentication systems running simultaneously:

**Generation 1: "ssoprd" (The Fossil)**

The endpoint named "ssoprd" — which you'd think stands for "SSO Production" — is actually a **DD Perks sweepstakes login page.** It serves a 149-byte HTML page that says "Application is running" with Akamai mPulse analytics. Hit `/login` and you get a form asking for your DD Perks email and password to sign into the "Sip. Peel. Win Sweepstakes."

The sweepstakes is long over. The login page is still there. The production SSO endpoint is a dead sweepstakes.

**Generation 2: Spring Authorization Server (The Real One)**

The actual modern auth lives on `social-ssoprd`, `social-ssopreprod`, and `social-ssostg`. These endpoints expose their full OIDC discovery documents — which means I can read their entire authentication architecture from a single `curl`:

- Authorization code flow, client credentials, refresh tokens, device authorization, token exchange
- PKCE with S256, DPoP (Demonstrating Proof-of-Possession), mutual TLS
- Pushed Authorization Requests (PAR)
- One fun inconsistency: the token endpoint is `/oauth/token` (no `2`), but everything else is `/oauth2/`. Someone refactored and missed one.

The 403 on the social-sso root isn't Akamai WAF — it's the application itself. JSESSIONID cookies are set on the 403 response. Java backend. They just don't want you looking at it. The OIDC discovery document, though? Wide open.

**Generation 3: Auth0 (The Experiment)**

`auth0-stg.dunkindonuts.com` CNAMEs to `d-7p5rilj85g.execute-api.us-east-1.amazonaws.com`. An Auth0 staging instance on AWS API Gateway. Someone proposed Auth0 at a meeting once. The DNS record is still here.

Three generations of authentication. One of them is a dead sweepstakes. This is enterprise software.

### QA Bypasses Akamai

Remember the 47-SAN cert with all the development environments? I actually probed those environments. Here's how their SDLC topology works:

| Environment | CDN | IP | Status |
|---|---|---|---|
| www | Akamai e5079 | 23.203.213.158 | Normal |
| dev2 | Akamai e5079 | 23.203.213.158 | Normal |
| **qa** | **NONE** | **44.221.191.180** | **Bare AWS** |
| qa2 | Akamai e5079 | 23.203.213.158 | Normal |
| staging | Akamai (blocked) | 23.203.213.158 | 403 AkamaiGHost |
| staging3 | Akamai e5079 | 23.203.213.158 | Normal |
| **uat** | **NONE** | **216.255.76.18** | **Dead** |

QA goes **directly to AWS.** No CDN. No WAF. No Akamai. And it's using a completely different TLS certificate — an Amazon RSA wildcard (`*.dunkindonuts.com`) instead of the GeoTrust 47-SAN cert that everything else uses. This cert also covers `*.awsprd.dunkindonuts.com`, `*.awsstg.dunkindonuts.com`, and `*.awspt.dunkindonuts.com` — suggesting there's a parallel AWS-native deployment that doesn't use Akamai at all.

QA's error pages helpfully include `Apache Server at qa.dunkindonuts.com Port 80`. Port 80. Over TLS. There's a load balancer in front doing TLS termination, and the backend Apache thinks it's on port 80. Classic.

UAT is even better. `whois 216.255.76.18` comes back as **IBM Cloud Managed Application Services** on the Verizon Business / DIGEX-BLK-2 network. A completely different cloud from everything else. UAT is unreachable — no HTTP, no TLS, nothing. It's a ghost IP on an IBM managed hosting block. This was the pre-AWS world.

### The CAAS Graveyard

Remember `fps.dunkinbrands.com`? The mystery service on an AWS ELB named `caas-prod-dunkinbrands-com`? I found its roommate.

`rbos.dunkinbrands.com` CNAMEs to the exact same ELB. Both dead. All ports closed. The CAAS platform — whatever it was — has been fully decommissioned. Two services, one ELB, zero heartbeats.

And the Genesis platform? `genesisproduction.dunkinbrands.com` and `genesissandbox.dunkinbrands.com` both return NXDOMAIN. Not just dead — removed from DNS entirely. Genesis has been un-created.

### ddmdev: The Secret Twin

CT logs revealed that `ddmprod` has a sibling: **ddmdev** (Dunkin' Donuts Mobile Development). It mirrors the production platform exactly — same services (ulink, mapi-dun, ode, swi), same Akamai edge configuration — but in four development sub-environments: `dev`, `dlt-dev`, `dlt-qa`, and `qa`.

And here's the best part: `swagger.ddmdev.dunkindonuts.com` resolves to **34.237.71.65** — a bare AWS IP with **no CDN in front of it.** Every other service in the entire Dunkin' infrastructure is behind either Akamai or Cloudflare. The Swagger API docs are just... sitting there. On a naked EC2 instance. In production DNS.

I haven't probed what it serves yet. It's the single most interesting door I haven't opened.

### The Menu Pricing API Is a Fortress

`menu-pricing-prd.dunkindonuts.com` is a Spring Boot REST API behind Akamai. I threw everything at it: Spring Boot actuator endpoints (`/actuator`, `/actuator/health`, `/actuator/env`, `/actuator/beans`, `/actuator/mappings`), Swagger paths (`/swagger-ui`, `/v2/api-docs`, `/v3/api-docs`), common API routes (`/api/menu`, `/api/pricing`, `/api/stores`), GraphQL endpoints.

Every. Single. Path. Returns. **401 Unauthorized.**

Spring Security catches the request before it even hits the router. The error JSON is clean — just `{"timestamp":"...","status":401,"error":"Unauthorized","path":"/whatever"}`. No stack traces, no version numbers, no debug info. Identical behavior across `menu-pricing-prd`, `menu-pricing-stg`, and `menu-pricing-prd1` (the redundant instance).

Someone on the Dunkin' platform team actually read the Spring Security documentation. I'm genuinely impressed. This is the most professionally secured service in their entire infrastructure, and it serves menu prices.

### The Vanity Domain Empire

Dunkin' owns a small fleet of vanity domains that all redirect to `dunkindonuts.com`:

| Domain | What It Was | Where It Goes |
|--------|-------------|---------------|
| `dunkinrewards.com` | Rewards program | → `/en/dunkinrewards` |
| `ddperks.com` | Old loyalty program | → `/en/dd-perks` → `/en/dunkinrewards` (double redirect!) |
| `dunkinperks.com` | Also old loyalty | → `/content/dunkindonuts/en/responsive/ddperks/splashpage.html` → chain of 3 more redirects |
| `dunkinemail.com` | Email signup | → `/content/dunkindonuts/en/responsive/dunkin_email.html` → dd-perks registration → dunkinrewards registration → **403** |
| `dunkinrun.com` | Campaign domain | → `/content/dunkindonuts/en.html` → `/en` |
| `ddglobalfranchising.com` | Franchising (old) | → `global.dunkinfranchising.com/en` |
| `dunkinfranchising.com` | Franchising | → `franchising.inspirebrands.com/dunkin` |
| `dunkinnation.com` | Dunkin' Nation | HTTPS dead, HTTP redirects to itself forever |

`dunkinemail.com` is the champion. It goes through FIVE redirects: the apex domain, then www, then a legacy CMS path, then dd-perks registration, then dunkin rewards registration, and finally lands on a **403 Forbidden.** You can't even sign up for their email list via their email signup domain. The redirect chain is a fossil record of three rebrands.

The TLS certs on these vanity domains revealed two previously unknown domains: **`clubdunkin.com`** and **`*.dunkindonuts.co.uk`** (they have a UK domain!). A different cert on `dunkinnation.com` covers **`*.dnkn.com`** and **`*.lsmnow.com`** — two domains I've never seen mentioned anywhere. The investigation continues.

### The Full Vendor Census

By Wave 2 the vendor list has grown considerably:

| Vendor | What They Do for Dunkin' |
|--------|-------------------------|
| Branch.io | Deep linking |
| OLO | Online ordering (Dunkin') |
| Tillster | Online ordering (Baskin-Robbins, different vendor!) |
| CardFree | THE ENTIRE MOBILE APP |
| Akamai | CDN + WAF |
| Cloudflare | CDN for franchisee portal + login |
| Proofpoint | Email security |
| DigiCert / GeoTrust | TLS certs |
| AWS | Everything that isn't on something else |
| Microsoft Azure | International site (just that one) |
| IBM Cloud | UAT (dead) |
| IPR Software | Investor relations site |
| ServiceNow | Customer chat (`inspirecustomer.service-now.com`) |
| Paradox AI | Recruiting / careers |
| Adobe Analytics | Web analytics (Omniture) |
| Salesforce Marketing Cloud | Email marketing |
| WeRecognize | Employee recognition |

**Seventeen vendors.** To sell donuts. And mango drinks. The international site runs on Azure — a completely different cloud from everything else — because apparently "international" means "different everything." The employee recognition platform is literally called WeRecognize. I can't make this up.

## Wave 3: I Opened Every Door

I ran 16 more probe scripts. Every mystery from Wave 2 — every "we should come back to this later" — I came back. I probed the sister brands. I probed the ghost domains. I probed the swagger endpoint. I probed things that hadn't been probed since the Obama administration. Here's what I found.

### The Restaurant Administration Portal (star.dunkinbrands.com)

Remember `star.dunkinbrands.com`? The mystery service from Wave 2 that only answered GET and returned 405 on everything else? I finally captured the response body.

It's a login page. Not just any login page. It's the **Restaurant Administration Portal (RAP)** — an internal tool for Dunkin' franchise operators. The full 18,447-byte HTML came back with a CrunchTime integration login form asking for:

- **Username** (your CrunchTime username)
- **Password** (your CrunchTime password)
- **EntityID** (your four-digit CrunchTime store ID, e.g., 0022 or 1234)

The submit button POSTs to `/User/LogInCrunchTime`. On success, it redirects to `/dashboard`. There's also an email-based OTP flow that calls... and I am not making this up... **`/User/GenrateOTPForUser`**.

`Genrate`. Not "Generate." `Genrate`.

This is a production ASP.NET Core application serving real franchise operators at 18,000+ Dunkin' locations and someone spelled "Generate" wrong in the API endpoint name. And they can never fix it because every franchise operator's browser has the JavaScript that calls `GenrateOTPForUser` cached. The typo is load-bearing. It will outlive us all.

The page also includes Google reCAPTCHA, jQuery 3.5.1 loaded from CloudFront, an Akamai mPulse RUM beacon (API key: `GFCZV-BTVLG-LZNSL-B55G9-NWDGT`), and a CSRF token baked right into the HTML. The staging instance at `star-stg.dunkinbrands.com` is also live and presumably also can't spell "Generate."

**CrunchTime**, by the way, is a restaurant operations platform. It handles inventory, food cost tracking, scheduling — the boring stuff that actually makes restaurants work. Dunkin' trusts them with everything. And CrunchTime trusts Dunkin' to spell "Generate." Both parties have been let down.

### The Swagger Editor (swagger.ddmdev.dunkindonuts.com)

This was supposed to be the big one. The "single most interesting door I haven't opened" from Wave 2. A Swagger endpoint on a bare EC2 instance with no CDN protection. I built an entire probe script for it — DNS across four resolvers, reverse DNS, whois, TLS cert inspection, 28-path enumeration, HTTP method sweeps, nmap port scanning, banner grabbing.

It's a Swagger Editor.

Not Swagger UI. Not API documentation. A **Swagger Editor** — the tool you use to *write* API specs, not the thing that *serves* them. It returned a 3,540-byte HTML page, served by nginx, with a `Last-Modified` date of **December 23, 2019.**

Some developer, five days before the world rang in 2020, spun up an nginx container on a bare EC2 instance, dropped the Swagger Editor static files in it, and walked away. That was over six years ago. The instance is still running. The wildcard cert (`*.ddmdev.dunkindonuts.com`) is still being renewed. Someone is presumably still paying AWS for this instance. It has survived a pandemic, a parent company acquisition, and at least three generations of infrastructure. It serves no purpose. It just exists, like a donut-shaped Voyager probe drifting through the cloud.

The nmap scan failed because nmap isn't available in my container image (oops), but banner grabs on ports 80, 443, 8080, 8443, 3000, 5000, and 9090 all came back empty. It's just port 443, nginx, and the ghost of a developer who wanted to edit some YAML in the browser.

### The SWI Mystery: Even More Mysterious

Wave 2 found SWI — an unknown service running in 6+ environments across the ddmprod and ddmdev platforms. I threw 35 paths at it across every live environment. API paths. Health checks. Swagger. Actuator. Login. Auth. Webhook. Push. Message. Even `/swi` and `/SWI`.

**Every. Single. Path. Returns. 404.**

Not 403 (blocked). Not 401 (auth required). 404 — "nothing here." Across prod, preprod, dev, and qa. All returning identical 728-byte HTML error pages. The dlt-dev and dlt-qa environments are even weirder — they return 503 Service Unavailable on everything, suggesting those sub-environments have been taken down while the main ones keep running.

The headers confirm it's a **Ruby on Rails** application:

```
Server: nginx
Status: 404 Not Found
X-Request-Id: c59fd0c8-ab78-4f11-8758-b57ba3a0ee1a
X-Runtime: 0.004005
X-N: S
```

`X-Runtime` and `X-Request-Id` are classic Rails. The `Status` header in the response is also a Rails-ism. This is a Rails app, running on nginx, behind Akamai, in production, that does... nothing visible. Every route is behind authentication or the app genuinely has no public-facing routes. The cert reveals SWI shares infrastructure with the Mobile API (mapi-dun), the Order Delivery Engine (ode), and the Universal Links service (ulink). It's a first-class citizen of the mobile platform that does nothing anyone can see from outside.

Six environments. Actively maintained. Purpose: classified. SWI remains this investigation's Area 51.

### Sonic Put a Slack Message in DNS

I enumerated DNS TXT records for all six Inspire Brands siblings. Most of what I found was normal: SPF records, DKIM selectors, domain verification strings for Google, Facebook, Adobe, Apple, Atlassian.

Then I got to Sonic Drive-In.

Sonic has **33 TXT records.** That's already a lot. But one of them is:

```
"[6:20 PM] Nelson, Brandi     atlassian-domain-verification=ePV5FzMQVHW78z2fSa9NUn8GwnrxUxwaPVUjsYP4bWfQliM21X7G4LMCvG65MgvF"
```

Read that again. That's a **Slack message pasted into a DNS record.** Someone named Brandi Nelson sent the Atlassian domain verification string in a Slack or Teams channel at 6:20 PM, and whoever was adding it to DNS just... copied the entire message. Including the timestamp. Including Brandi's name. Into the TXT record. That was committed to production DNS.

Every DNS resolver on the internet can now tell you that Brandi Nelson sent that verification string at 6:20 PM. It's been there long enough that it's probably been replicated to thousands of recursive resolvers worldwide. Brandi Nelson is now part of the global DNS infrastructure. I hope she knows.

They have another copy of the same Atlassian verification string *without* the chat metadata, so they presumably noticed at some point and added a clean one. But they never deleted the Brandi version. Both records coexist in DNS, two copies of the same key, one wearing Brandi Nelson's name like a digital tramp stamp.

### wsapi: Somebody Else's Certificate

`wsapi.dunkinbrands.com` resolves to 54.172.180.235 (AWS). It returns 404 on everything with a `server: envoy` header and two custom headers:

```
x-theorem-auth: nil
x-theorem-platform: nil
```

Theorem. Not Dunkin'. I pulled the TLS certificate:

```
subject=CN=api-test.theoremlp.com
issuer=C=US, O=Let's Encrypt, CN=R13
```

The certificate is for **`api-test.theoremlp.com`** — a test API belonging to **Theorem LP**, a digital product consultancy. Dunkin's Web Service API subdomain is serving another company's test certificate. The cert expires April 21, 2026 — meaning someone at Theorem is still renewing it. On Dunkin's infrastructure. For Dunkin's subdomain.

Either Theorem is a current vendor who configured something wrong, or they *were* a vendor and nobody cleaned up the DNS when the engagement ended. Either way, `wsapi.dunkinbrands.com` has been answering "I'm Theorem LP's test API" to anyone who bothers to check the certificate, and apparently nobody has bothered.

### One Company, Seven Brands, One Email Pipe

I compared email infrastructure across ALL seven Inspire Brands entities: Dunkin', Baskin-Robbins, Arby's, Buffalo Wild Wings, Sonic, Jimmy John's, and the Inspire Brands parent.

They are **all identical.**

| Configuration | Value (same for all 7) |
|---|---|
| MX Provider | Proofpoint (`mxa-00919702.gslb.pphosted.com`) |
| SPF Macro | `include:%{ir}.%{v}.%{d}.spf.has.pphosted.com` |
| DMARC Policy | `p=reject; rua=mailto:dmarc_rua@emaildefense.proofpoint.com` |
| M365 DKIM | `selector1/selector2` → `inspirebrands.onmicrosoft.com` |

Same Proofpoint tenant. Same Microsoft 365 tenant. Same DMARC reporting. Every email from every brand — Dunkin' promotions, Arby's coupons, BWW game day alerts, Sonic happy hour notices, Jimmy John's delivery confirmations — all flow through the exact same email infrastructure. One pipe. Seven restaurant chains. 44,000+ locations.

Dunkin' uses legacy Proofpoint MX naming (`psmtp.com`) while the other brands use modern naming (`pphosted.com`), suggesting Dunkin' was already a Proofpoint customer before the Inspire Brands acquisition consolidated everyone onto one tenant. They migrated the config but left the old MX records because changing MX records is scary and donuts don't require bravery.

For transactional email, the brands branch out slightly: Arby's, BWW, Sonic, and Jimmy John's all use **SendGrid** (each with their own account). Sonic also has **Mailchimp/Mandrill**. Jimmy John's has **Mailgun** as a side channel. Dunkin' and BWW both use **Salesforce Marketing Cloud** for engagement tracking.

The KnowBe4 phishing awareness training verification token is the same across Arby's, BWW, and Sonic: `0c00dc3beaeabc5a1bb3e17db0f29f45`. Same security training platform, same account, three brands. If you hack the phishing training, you hack the phishing training for three fast food chains at once.

### The Center: Where Franchisees Learn About Bakery Equipment

`thecenter.dunkinbrands.com` is an **Adobe Experience Manager** learning portal behind CloudFront. The TLS cert says `O=Inspire Brands, Inc., L=Sandy Springs` — Sandy Springs, Georgia is Inspire Brands' headquarters.

The portal serves franchisee training content. Wayback Machine captured the content paths:

- `/content/combo/us/en/header/learning-path-combo/dunkin-learning-path-11-27.html` — the "Dunkin Learning Path" from November 2027
- `/content/combo/us/en/home/dunkin-equipment/bakery-equipment.html` — **bakery equipment training**
- `/content/combo/us/en/header/readiness/spring-readiness-february-21-april-30.html` — "Spring Readiness" seasonal training

There's a course for bakery equipment. There is a corporate learning management system, hosted on Adobe Experience Manager, running on AWS behind CloudFront, registered to Inspire Brands of Sandy Springs, Georgia, and it has a module about bakery equipment. Franchisees log in with Okta, navigate to the learning path, and learn about the equipment that makes the donuts. This is the circle of life.

The AEM admin login page at `/libs/granite/core/content/login.html` returns 200 and serves 12,753 bytes of HTML. The security-sensitive paths (`/crx/de`, `/system/console`, `/bin/querybuilder.json`) are properly 404'd — someone configured the AEM dispatcher correctly. But the fact that the admin login *page* is accessible means you can see the Granite UI login screen even if you can't do anything with it. It's like pressing your face against the window of a locked store.

### The Ghost Domain Graveyard

I probed every vanity domain found in the Wave 2 cert SANs. The results are a masterclass in "we registered this domain for a campaign in 2004 and we're still paying for it."

**dnkn.com** — Created December 20, 2003. Still resolves. Still redirects to dunkindonuts.com. The TLS certificate has been **expired since September 28, 2022.** Three and a half years of expired cert. The cert's CN is `brglobalfranchising.com` with SANs covering `*.dnkn.com`, `*.lsmnow.com`, `catering.dunkindonuts.com`, and `dunkinnation.com`. Nobody has renewed this cert because nobody remembers this cert exists. It just sits there, serving browsers a security warning, redirecting them to a donut website.

**lsmnow.com** — "Local Store Marketing." Created February 5, 2004. This one redirects to `lsm-prod-idp.dunkinbrands.com/my.policy` — that's an **F5 BIG-IP access policy manager**, which is basically a VPN login page. The MX record points to `mail.flairpromo.com`, a promotional marketing company. Twenty-two years ago, someone at Dunkin' Brands had a vision for a "Local Store Marketing" portal. They bought a domain. They set up an F5 appliance. They hired Flair Promo to handle the emails. The portal is now a redirect to a login page that probably doesn't work anymore. But the DNS is eternal.

**clubdunkin.com** — Created September 3, 2020. Redirects to `www.dunkindonuts.com/en/clubdunkin`. A loyalty program that existed for approximately the blink of an eye before being folded into Dunkin' Rewards.

**dunkinnation.com** — The redirect loop. HTTP root → 301 → HTTPS root → 301 → `https://www.dunkinnation.com/` → connection refused. The www subdomain is dead but the root A record still points to a running server that dutifully redirects you to the dead subdomain. Forever. It will keep redirecting until either the server dies or the sun explodes. Dunkin' Nation has become a donut-shaped ouroboros.

### BAM: Another Portal Behind Another SSO

`bam.dunkinbrands.com` immediately 302-redirects to:

```
https://sso.inspirepartners.net/app/inspirepartners_bam_1/exk938s08y7yt4V9f697/sso/saml
```

That's **Okta** at `sso.inspirepartners.net`. The app ID is `inspirepartners_bam_1`. Whatever BAM is (Brand Asset Management? Business Analytics Module? Bagel Acquisition Matrix?), it's an Inspire Partners internal application authenticated via Okta SAML.

The server runs **IIS 10.0** with **ASP.NET 4.0.30319** — the .NET Framework version, not .NET Core. The TLS cert reveals two wildcard SANs that didn't appear anywhere else: `*.corporateportal.dunkinbrands.com` and `*.franchisee.dunkinbrands.com`. There's a whole tier of portal infrastructure we haven't even started mapping.

### The Graveyard Graveyard (Legacy Infrastructure)

Three legacy services are DEAD on AT&T IP space:

| Service | IP | Status |
|---|---|---|
| `sts.dunkinbrands.com` (Security Token Service) | 12.170.52.233 | Dead. CNAME: `stsprod.itdns.dunkinbrands.com` |
| `sslvpn.dunkinbrands.com` (SSL VPN) | 12.170.52.152 | Dead. Same AT&T /24 as STS. |
| `citrix.dunkinbrands.com` (Citrix Gateway) | 164.109.80.73 | Dead. |

These are fossils from the pre-cloud era. AT&T managed hosting. ADFS federation. Citrix remote access. This was Dunkin' Brands' IT infrastructure before AWS existed, before Inspire Brands existed, before the donuts dropped from the name. The DNS records survive like petroglyphs, pointing at IP addresses that will never answer again.

The STS endpoint has a CNAME to `stsprod.itdns.dunkinbrands.com` — that's an internal DNS naming convention that suggests there was once an `ststest.itdns` and `stsstg.itdns` too. A whole ADFS topology for a donut company, running on AT&T iron, serving SAML tokens to people who needed to check the fryer schedule. All gone.

SmartSolve is the interesting one. IP 74.199.217.32 (same /24 subnet as the identity provider at .23). It responds to OPTIONS, PUT, and DELETE with HTTP 200 on HTTPS, but GET and POST just... hang and die. HTTP GET returns 302. Something is alive in there. Something that answers to unusual HTTP methods but refuses normal ones. SmartSolve is an "Equipment Quality Management System" — it manages quality workflows for manufacturing. What a donut chain needs with an EQMS is between them and their god.

### The Sandbox Is Dead

I probed all 8 sandbox endpoints from the CT logs:

```
DEAD  loyalty-api.sandbox.dunkindonuts.com
DEAD  loyalty-mock-api.sandbox.dunkindonuts.com
DEAD  rewards-api.sandbox.dunkindonuts.com
DEAD  oats-api.sandbox.dunkindonuts.com
DEAD  oats-ws.sandbox.dunkindonuts.com
DEAD  splunkelb.sandbox.dunkindonuts.com
DEAD  swagger.sandbox.dunkindonuts.com
DEAD  ecselb.sandbox.dunkindonuts.com
```

All NXDOMAIN. The entire `sandbox.dunkindonuts.com` environment has been decommissioned. Wayback shows they were alive as recently as 2022-2023 — the OATS WebSocket returned 404 XML, the sandbox Swagger had a robots.txt. There was an entire parallel universe of loyalty APIs, rewards systems, and Splunk monitoring, and now it's gone. Eight services. Eight NXDOMAIN. The sandbox didn't survive the winter.

### The Full Vendor Census (Updated)

| Vendor | What They Do | Brands |
|--------|-------------|--------|
| Branch.io | Deep linking | Dunkin' |
| OLO | Online ordering | Dunkin' |
| Tillster | Online ordering | Baskin-Robbins |
| CardFree | THE ENTIRE MOBILE APP | Dunkin' |
| CrunchTime | Restaurant operations (RAP) | Dunkin' |
| Akamai | CDN + WAF | Dunkin', BR |
| Cloudflare | CDN + DNS | Arby's, BWW, Sonic, JJ, franchising |
| Proofpoint | Email security | ALL 7 brands |
| Microsoft 365 | Corporate email (DKIM) | ALL 7 brands |
| SendGrid | Transactional email | Arby's, BWW, Sonic, JJ |
| Salesforce Marketing Cloud | Email marketing | Dunkin', BWW, JJ, Inspire |
| Mailchimp/Mandrill | Email | Sonic |
| Mailgun | Email | Jimmy John's |
| DigiCert / GeoTrust | TLS certs (mobile) | Dunkin' |
| Let's Encrypt | TLS certs (dev) | Dunkin' dev, Arby's |
| AWS | Infrastructure | Dunkin', BR, most brands |
| Microsoft Azure | International site | Dunkin' (just that one) |
| IBM Cloud | UAT (dead) | Dunkin' (dead) |
| IPR Software | Investor relations + news | Dunkin', BR |
| ServiceNow | Customer chat | All (inspirecustomer) |
| Paradox AI | Recruiting / careers | Dunkin' |
| Adobe Analytics | Web analytics | Dunkin' |
| Adobe Experience Manager | Franchisee training (The Center) | Dunkin' |
| Okta | SSO (internal apps) | Inspire Partners |
| KnowBe4 | Phishing training | Arby's, BWW, Sonic |
| Theorem LP | ??? (cert on wsapi) | Dunkin' |
| WeRecognize | Employee recognition | Dunkin' |
| F5 Networks | Load balancing (legacy) | Dunkin' |
| Flair Promo | Local Store Marketing | Dunkin' |

**Twenty-nine vendors.** Up from seventeen. Almost doubled. Twenty-nine companies involved in the operation of six fast food chains that share the same email pipe. If you include the defunct ones (AT&T managed hosting, IBM Cloud), we're at thirty-one. There are more vendors than there are items on most of these restaurants' menus.

## The Numbers

| Metric | Count |
|--------|-------|
| Probe scripts run | 33 |
| Artifact directories | 30 |
| Entities in the graph | 77 |
| Edges | 78 |
| Clusters | 15 |
| Anomalies | 33 |
| Vendors identified | 29 |
| Dead services | 19 |
| Redirect loops | 2 |
| Expired certificates | 1 (3.5 years expired) |
| Slack messages in DNS | 1 |
| Typos in production endpoints | 1 (GenrateOTPForUser) |
| Swagger Editors forgotten since 2019 | 1 |
| Wrong company's certificate on Dunkin' infrastructure | 1 |
| Fast food brands sharing one email pipe | 7 |

This started because a Dunkin' ad pretended a toddler typed on a phone.

## Methodology

All probes ran inside containerized environments (`podman run --rm --dns 8.8.8.8 investigator`). DNS enumeration, HTTP redirect tracing, TLS certificate inspection, certificate transparency log queries, Wayback Machine CDX queries, Apple App Site Association file retrieval, Reddit public API, iTunes Search API, nmap port scanning, Spring Boot actuator probing, OIDC discovery endpoint enumeration, cross-brand DNS/DKIM/DMARC comparison, AEM path enumeration, Okta SSO redirect capture. 33 probe scripts across 3 waves. Zero exploitation, zero auth bypass, zero interaction with any service beyond reading what they publicly serve.

I just looked at what was already there. Dunkin' made it easy.

## Files

- **[GRAPH.md](GRAPH.md)** — The serious version. 77 entities, 15 clusters, 33 anomalies. Structured for machines.
- **`intake-2026-04-13/`** — The evidence. Screenshots and the URL that started all of this.
- **`artifacts/`** — Raw probe output from 30 artifact directories. DNS, HTTP, certs, OSINT, CT logs, SSO discovery, menu pricing API, QA environments, legacy services, vanity domains, sister brands, ghost domains, email infrastructure, POS APIs, sandbox graveyards.
- **`scripts/`** — 33 reproducible probe scripts. Run them yourself. Everything is containerized.
