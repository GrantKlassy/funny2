# I Reverse-Engineered Dunkin's Entire Digital Infrastructure Because Their Reddit Ad Annoyed Me

# [EXPLORE THE INTERACTIVE NETWORK GRAPH](https://grantklassy.github.io/funny2/investigations/dunkin/graph/network-visualization.html)

77 entities, 78 connections, 15 clusters. Every vendor, every subdomain, every cert SAN — connected. One Reddit ad, fully deconstructed.

I'm scrolling Reddit. It's late. I see a Dunkin' ad. Fine. But then I see the *other* one. And then I click it.

| The ad | The "toddler" | The landing page |
|:---:|:---:|:---:|
| <img src="investigations/dunkin/intake-2026-04-13/dunkin1.jpg" width="100%"> | <img src="investigations/dunkin/intake-2026-04-13/dunkin2.jpg" width="100%"> | <img src="investigations/dunkin/intake-2026-04-13/dunkin3.jpg" width="100%"> |

Read the middle one. Read it again. A corporate account — verified, promoted, paid money to put this in my feed — posted this:

```
Wjkhsgjkhdgkhkjfhgdfgdogihdgcatmomdfgddgjkk
kidogsyjkdffkkjkddadadadadadadadamommmmmmmdf
d7766Vvvqg8888
AAAAAAAAAaaaaaasssvIFFGHF7ghfh88
```

Followed by "Sorry, toddler had my phone."

No. No, your toddler did not have your phone. Your *copywriter* had your phone. And I can prove it.

### The Toddler Is a Lie

I ran the "gibberish" through keyboard distribution analysis. If a toddler actually mashed a keyboard, you'd expect roughly equal hits across all three rows — they don't know where the home row is. They're a toddler. They eat crayons.

| Keyboard Row | Expected (toddler) | Actual |
|---|---|---|
| Top row (qwerty) | ~33% | **10%** |
| Home row (asdf) | ~33% | **77%** |
| Bottom row (zxcv) | ~33% | **12%** |

**Seventy-seven percent home row.** That's a grown adult resting their fingers on asdfghjkl and wiggling them around. The gibberish also contains strategically embedded words: `cat`, `dog`, `kid`, `mom`, `dad`, `dada` — all family-and-pet themed. All placed to make you go "aww" instead of "this is an ad."

The toddler is a psyop. Dunkin' is running narrative warfare on Reddit.

### But Then I Clicked It

The URL was `ulink.prod.ddmprod.dunkindonuts.com`. That's a subdomain four levels deep with internal environment naming. `prod.ddmprod`? Production inside another production? What is `ddmprod`?

**ddmprod** stands for **Dunkin' Donuts Mobile Production.** The name predates their 2018 rebrand from "Dunkin' Donuts" to just "Dunkin'" — the ghost of "Donuts" lives on in their DNS. The TLS certificate on this one subdomain lists every other service in their mobile platform. I mapped their entire backend from a single `openssl s_client`.

So I did what any reasonable person would do. I opened a container and started running dig. 33 probe scripts later, here are the highlights.

### GenrateOTPForUser

`star.dunkinbrands.com` — a mystery service from early probing that only responded to GET — turned out to be the **Restaurant Administration Portal (RAP)**. It serves a full 18,447-byte login page for Dunkin' franchise operators. The form has three fields: CrunchTime Username, CrunchTime Password, and a 4-digit store EntityID. The submit button POSTs to `/User/LogInCrunchTime`.

There's also an email-based one-time password flow. The endpoint it calls is **`/User/GenrateOTPForUser`**.

`Genrate`. Not "Generate." *Genrate.*

This is a production ASP.NET Core application serving 18,000+ Dunkin' locations and someone spelled "Generate" wrong in the API endpoint name. They can never fix it because every franchise operator's browser has the JavaScript that calls `GenrateOTPForUser` cached. The typo is load-bearing. It will outlive us all.

### Sonic Put a Slack Message in DNS

I enumerated DNS TXT records for all six Inspire Brands siblings. Most were normal — SPF, DKIM, domain verification strings. Then I got to Sonic Drive-In. 33 TXT records. One of them is:

```
"[6:20 PM] Nelson, Brandi     atlassian-domain-verification=ePV5FzMQVHW78z2fSa9NUn8GwnrxUxwaPVUjsYP4bWfQliM21X7G4LMCvG65MgvF"
```

Someone named **Brandi Nelson** sent the Atlassian verification string in a Slack or Teams channel at 6:20 PM, and whoever was adding it to DNS just... copied the entire message. Including the timestamp. Including Brandi's name. Into the TXT record. That was committed to production DNS.

Every DNS resolver on the internet can now tell you that Brandi Nelson sent that verification string at 6:20 PM. She's part of the global DNS infrastructure now.

They added a clean copy of the same key later. But they never deleted the Brandi version. Both records coexist. Two copies of the same key, one wearing Brandi Nelson's name like a digital tramp stamp.

### Somebody Else's Certificate

`wsapi.dunkinbrands.com` — Dunkin's "Web Service API" — returns 404 with custom headers: `x-theorem-auth: nil`, `x-theorem-platform: nil`. Theorem. Not Dunkin'. I pulled the TLS certificate:

```
subject=CN=api-test.theoremlp.com
issuer=C=US, O=Let's Encrypt, CN=R13
```

Dunkin's subdomain is serving **Theorem LP's** test API certificate. A completely different company's cert. Someone at Theorem is still renewing it. On Dunkin's infrastructure. For Dunkin's subdomain. Nobody has noticed.

### The Swagger Editor Somebody Left Running in 2019

`swagger.ddmdev.dunkindonuts.com` resolves to a bare EC2 instance with no CDN protection. Every other service in the entire Dunkin' infrastructure is behind Akamai or Cloudflare. This one is just... naked on the internet.

I built an entire probe script for it — 28-path enumeration, HTTP method sweeps, nmap, banner grabs.

It's a **Swagger Editor.** Not API docs. A Swagger *Editor* — the tool you use to write API specs. 3,540 bytes of HTML, served by nginx, with a `Last-Modified` date of **December 23, 2019.**

Some developer spun up an nginx container on a bare EC2 instance five days before 2020 and walked away. That was over six years ago. The instance is still running. The cert is still being renewed. Someone is presumably still paying AWS for it. It has survived a pandemic, a parent company acquisition, and at least three generations of infrastructure. It serves no purpose. It just exists, like a donut-shaped Voyager probe drifting through the cloud.

### SWI: Area 51

The ddmprod platform has a service called `swi`. It's LIVE in production, preprod, dev, and qa. Six environments. Actively maintained. I threw 35 paths at it across every environment — API endpoints, health checks, Swagger, actuator, login, auth, webhook, push, message, even `/swi` and `/SWI`.

**Every. Single. Path. Returns. 404.**

It's a Ruby on Rails app behind Akamai. It shares a TLS certificate with the Mobile API, the Order Delivery Engine, and Universal Links — it's a first-class citizen of the mobile platform. Six environments. Actively maintained. 35 paths probed. Purpose: completely unknown. SWI is this investigation's Area 51.

### One Email Pipe, Seven Restaurant Chains

All seven Inspire Brands entities — Dunkin', Baskin-Robbins, Arby's, Buffalo Wild Wings, Sonic, Jimmy John's, and the parent company — use **identical email infrastructure:**

Same Proofpoint tenant. Same Microsoft 365 tenant. Same SPF macro. Same DMARC policy. Every email from every brand — Dunkin' promotions, Arby's coupons, BWW game day alerts, Sonic happy hour notices — all through the exact same pipe. One pipe. Seven chains. 44,000+ locations.

The KnowBe4 phishing training token is the same across Arby's, BWW, and Sonic: `0c00dc3beaeabc5a1bb3e17db0f29f45`. Same account. If you hack the phishing training, you hack it for three fast food chains at once.

### The Redirect Graveyard

Dunkin' owns a fleet of vanity domains from campaigns past. They age like forgotten donuts.

**dnkn.com** (registered 2003) still resolves. Still redirects. The TLS certificate has been **expired since September 28, 2022.** Three and a half years of expired cert. Nobody has noticed because nobody remembers this domain exists.

**dunkinnation.com** is stuck in an infinite redirect loop: root → 301 → www → connection refused. The www subdomain is dead but the root keeps redirecting to it. Forever. A donut-shaped ouroboros.

**dunkinemail.com** goes through FIVE redirects — apex, www, legacy CMS path, dd-perks registration, dunkin rewards registration — and lands on a **403 Forbidden.** You can't sign up for their email list via their email signup domain.

**lsmnow.com** (registered 2004) redirects to an F5 BIG-IP access policy manager — a VPN login page for a "Local Store Marketing" portal. Twenty-two years old. The MX record points to a company called Flair Promo. The portal is a fossil. The DNS is eternal.

### The Dead Sweepstakes Running as "SSO Production"

I found three generations of authentication running simultaneously. The endpoint named `ssoprd` — which you'd think stands for "SSO Production" — is actually a **DD Perks "Sip. Peel. Win Sweepstakes" login page.** The sweepstakes is long over. The login page is still there.

Meanwhile, `auth0-stg.dunkindonuts.com` is an Auth0 staging instance on AWS API Gateway. Someone proposed Auth0 at a meeting once. The DNS record is still here.

Three generations of auth. One is a dead sweepstakes. One is a meeting that became a DNS record. This is enterprise software.

### Baskin-Robbins Is Literally Dunkin'

`baskinrobbins.com` resolves to the *exact same A records* as `dunkindonuts.com`. Same cert. Same Route 53 nameservers. Same box. You request `baskinrobbins.com` and the same server that serves `dunkindonuts.com` goes "oh, you wanted ice cream? Same building, different door."

### CardFree Runs Everything

The Dunkin' app's Android package is `com.cardfree.android.dunkindonuts`. The iOS entitlements are under `com.cardfree.ddnationalprd`. CardFree doesn't just handle payments. **CardFree IS the app.** Every time you tap "Order Ahead" you're interacting with a company you've never heard of. Dunkin' is a CardFree customer wearing a costume.

### Bakery Equipment Training on Adobe Experience Manager

`thecenter.dunkinbrands.com` is an AEM learning portal for franchisees. Content includes "Dunkin Learning Path," "Spring Readiness" seasonal training, and — I am not making this up — a module about **bakery equipment.** There is a corporate LMS, running on Adobe Experience Manager, behind CloudFront, registered to Inspire Brands of Sandy Springs, Georgia, and it has a course about the equipment that makes the donuts.

### 29 Vendors to Sell Donuts

| Vendor | Role |
|--------|------|
| Branch.io | Deep linking |
| OLO | Online ordering (Dunkin') |
| Tillster | Online ordering (Baskin-Robbins) |
| CardFree | THE ENTIRE MOBILE APP |
| CrunchTime | Restaurant operations (the GenrateOTP people) |
| Akamai | CDN + WAF |
| Cloudflare | CDN + DNS (other brands) |
| Proofpoint | Email security (all 7 brands) |
| Microsoft 365 | Corporate email (all 7 brands) |
| SendGrid | Transactional email |
| Salesforce Marketing Cloud | Email marketing |
| Mailchimp/Mandrill | More email (Sonic) |
| Mailgun | Even more email (Jimmy John's) |
| DigiCert / GeoTrust | TLS certs |
| Let's Encrypt | TLS certs (dev) |
| AWS | Infrastructure |
| Microsoft Azure | International site (just that one) |
| IBM Cloud | UAT (dead) |
| IPR Software | Investor relations + news |
| ServiceNow | Customer chat |
| Paradox AI | Recruiting |
| Adobe Analytics | Web analytics |
| Adobe Experience Manager | Bakery equipment courses |
| Okta | SSO (internal apps) |
| KnowBe4 | Phishing training |
| Theorem LP | ??? (their cert is on Dunkin's domain) |
| WeRecognize | Employee recognition |
| F5 Networks | Load balancing (legacy) |
| Flair Promo | Local Store Marketing (legacy) |

Twenty-nine companies involved in operating six fast food chains that share the same email pipe. There are more vendors than there are items on most of these restaurants' menus.

### The Numbers

| Metric | Count |
|--------|-------|
| Probe scripts run | 33 |
| Entities in the graph | 77 |
| Anomalies | 33 |
| Vendors identified | 29 |
| Dead services | 19 |
| Redirect loops | 2 |
| Expired certificates in production | 1 (3.5 years) |
| Slack messages in DNS | 1 |
| Typos in production API endpoints | 1 |
| Swagger Editors forgotten since 2019 | 1 |
| Wrong company's certificate on your domain | 1 |
| Fast food brands sharing one email pipe | 7 |

This started because a Dunkin' ad pretended a toddler typed on a phone.

![claude reacting to the findings](memes/claude-holy-shit.png)

*My AI research assistant, upon discovering that Dunkin' and Baskin-Robbins are the same server.*

---

All probes ran inside containerized environments. 33 scripts across 3 waves. Zero exploitation, zero auth bypass, zero interaction with any service beyond reading what they publicly serve. I just looked at what was already there.

**[Full investigation writeup](investigations/dunkin/README.md)** | **[GRAPH.md](investigations/dunkin/GRAPH.md)** (77 entities, 15 clusters, 33 anomalies) | **[Investigation directory](investigations/dunkin/)**
