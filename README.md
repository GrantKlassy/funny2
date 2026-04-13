# I Reverse-Engineered Dunkin's Entire Mobile Infrastructure Because Their Reddit Ad Annoyed Me

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

### But Then I Clicked It

Against my better judgment, I tapped the ad. The URL was:

```
https://ulink.prod.ddmprod.dunkindonuts.com/dunkin/orders/category/119
```

Wait. `ulink.prod.ddmprod.dunkindonuts.com`? That's not a normal marketing URL. That's a subdomain four levels deep with what looks like internal environment naming. `prod.ddmprod`? Production inside... another production? What is `ddmprod`?

So I did what any reasonable person would do. I opened a container and started running dig.

> **[EXPLORE THE INTERACTIVE NETWORK GRAPH](https://grantklassy.github.io/funny2/investigations/dunkin/graph/network-visualization.html)** — 56 entities, 57 connections, 12 clusters. Every vendor, every subdomain, every cert SAN — connected. Drag it. Zoom it. Search it. One Reddit ad, fully deconstructed in a force-directed D3.js visualization.

### What Is ddmprod?

**ddmprod** stands for **Dunkin' Donuts Mobile Production.** It's their entire internal mobile app platform. The name predates their 2018 rebrand from "Dunkin' Donuts" to just "Dunkin'" — the infrastructure team apparently didn't get the memo. Or didn't care. Either way, the ghost of "Donuts" lives on in their DNS.

Here's the thing about TLS certificates — they have to list every domain they cover. The cert on `ulink.prod.ddmprod.dunkindonuts.com` has a Subject Alternative Names list that reads like someone left the architecture diagram on a public bus:

| Service | What It Does |
|---------|-------------|
| `mapi-dun` | **Mobile API** — the actual app backend. This is the primary CN on the cert. `ulink` is just riding along. |
| `ulink` | **Universal Links** — the thing I clicked. Routes you to the app or the web depending on your device. |
| `ode` | **Order Delivery Engine** — exactly what it sounds like |
| `swi` | Nobody knows. LIVE in prod AND all dev environments. Actively maintained. Prod returns 404 — no default route, not dead. |
| `dun-assets` | Static asset CDN. Serves `dunkin_logo@2x.png` to the app. |
| `cloud` | Only seen in preprod via Wayback. Mysterious. |

All of these exist in both `prod` and `preprod` environments. The whole thing runs on **Akamai CDN** with **DigiCert ECC certificates** issued to **Dunkin' Brands, Inc., Canton, Massachusetts.**

I mapped 56 entities from one drink ad. I know more about Dunkin's mobile backend than most of their employees.

### The Three-Way Split

The `ulink` service is a Node.js/Express app that sniffs your User-Agent and makes a decision:

**If you're on an iPhone with the app installed:** iOS Universal Links kick in. The app opens directly to `dunkin://orders/category/119`. You never see a webpage. You're just suddenly looking at drinks.

**If you're on a phone without the app:** You get the interstitial page (the "GET THE APP" screen I screenshotted). The "Continue on App" button is the good part — it links to:

```
https://dunkin.smart.link/f6iexb4x5?destination=dunkin://orders/category/119
```

`dunkin.smart.link` — that's **Branch.io**, the deep linking vendor. They're the ones who make sure that if you install the app from the App Store, you still land on the right category page. Deferred deep linking. It's actually kind of clever, if you ignore everything else about this situation.

**If you're on a desktop or you're a bot:** HTTP 302 redirect to `www.dunkindonuts.com/en/mobile-app`. Go away, you're not buying a drink from your laptop.

### How Many Companies Does It Take to Sell a Mango Drink

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

### Why Was This Ad Targeted at Me?

The Wayback Machine answered this one. Historical snapshots of the `ulink` URLs preserved the full UTM parameters from previous campaigns:

```
utm_source=reddit
utm_medium=paidsocial
utm_campaign=dunkinrun
utm_content=interests
```

The targeting parameter is literally called `interests`. Reddit served me this ad because of my subreddit engagement patterns. Dunkin' paid Reddit to show me a fake toddler post based on an algorithmic guess about what I might enjoy.

Conversion tracking uses Reddit Click IDs (`rdt_cid` parameters) — unique identifiers appended to every ad click URL so Dunkin' can trace the journey from "saw ad on Reddit" to "ordered a drink in the app." There are at least 8 distinct `rdt_cid` values captured in Wayback from different campaign runs. Previous campaigns targeted categories 28, 53, and 70. Mine was 119.

### Bonus Round: The www Certificate

I checked the TLS cert on `www.dunkindonuts.com` for good measure. It lists **47 Subject Alternative Names.** Forty-seven. Including:

- `dev2.dunkindonuts.com`, `qa.dunkindonuts.com`, `qa2.dunkindonuts.com`, `staging.dunkindonuts.com`, `staging3.dunkindonuts.com`, `uat.dunkindonuts.com` — their entire development lifecycle is in this cert
- `ssoprd.dunkindonuts.com`, `social-ssoprd.dunkindonuts.com` — SSO infrastructure
- `menu-pricing-prd.dunkindonuts.com` — the menu pricing API, in production
- `franchiseecentral.dunkinbrands.com` — the franchisee portal
- `www.baskinrobbins.com`, `staging.baskinrobbins.com`, `qa.baskinrobbins.com` — Baskin-Robbins shares the cert

Nothing is exposed or exploitable. But the fact that you can learn the names of all their internal environments from a single `openssl s_client` command is... very Dunkin'.

But wait. 47 SANs means 47 live services on one certificate. Let me resolve every single one of them.

### I Resolved All 47 SANs and Most of Them Are Live

Nearly every domain on that cert resolves. Most of them are behind Akamai. But a few rebels broke free:

- **`qa.dunkindonuts.com`** goes DIRECT to AWS (`52.71.129.172`) — no Akamai. The QA team said "we don't need a CDN, we're just testing." Bold move.
- **`uat.dunkindonuts.com`** resolves to `216.255.76.18` — a completely different IP range from everything else. Contractor hosting? A managed testing vendor? Nobody knows. It doesn't respond to HTTPS.
- **`ssoprd.dunkindonuts.com`** is LIVE. HTTP 200. 149 bytes. It's the SSO redirect page for production. Just sitting there. Behind Akamai, at least.
- **`menu-pricing-prd.dunkindonuts.com`** returns a JSON 404 with Spring Boot security headers. It's a REST API for menu pricing. The endpoint exists. It works. It just doesn't know what you want because you didn't provide a path.
- **`star.dunkinbrands.com`** returns HTTP 405 — Method Not Allowed. It's an API that will only talk to you if you know the right HTTP verb. I do not know the right HTTP verb.
- **`fps.dunkinbrands.com`** has an AWS ELB called `caas-prod-dunkinbrands-com`. "CAAS" — Content As A Service? Connection refused. The ELB exists but nothing's home.

And then there's **`franchiseecentral.dunkinbrands.com`**. It's live. It's running ASP.NET behind Cloudflare and AWSALB. Its `Last-Modified` header says **July 12, 2016**. The franchisee portal has not been updated in ten years. It was built before the rebrand. It was built before the Inspire Brands acquisition. It may have been built before some of its franchise owners were born.

### Baskin-Robbins Is Literally Dunkin'

I figured while I was here, I'd check the Inspire Brands sister brands. Arby's, Buffalo Wild Wings, Sonic, Jimmy John's, Baskin-Robbins. Do any of them use the ddmprod pattern?

No. None of them. ddmprod is Dunkin'-only. Each sister brand has completely different infrastructure — different registrars, different CDNs, different cert authorities. It's like Inspire Brands acquired six restaurants and said "you guys figure out your own IT."

But then I looked at Baskin-Robbins more carefully and things got weird.

`baskinrobbins.com` resolves to **`52.0.33.13` and `35.169.92.22`**. Those are the same A records as `dunkindonuts.com`. The *exact same IPs*. I checked the cert — it's the same GeoTrust cert with the 47 SANs. Same Route 53 nameservers. Baskin-Robbins isn't just "sharing infrastructure" with Dunkin'. Baskin-Robbins IS Dunkin'. They're the same box. You request `baskinrobbins.com` and the same server that serves you `dunkindonuts.com` goes "oh, you wanted ice cream? Same building, different door."

The only difference: Dunkin' uses OLO for ordering (`whitelabel.olo.com`), but Baskin-Robbins uses **Tillster** (`www-br-us.tillster.com`). Two different ordering vendors for two brands on the same server. The server doesn't even know they're different companies.

### CardFree Runs Everything

Remember CardFree from the Apple App Site Association file? I said they handled "mobile payments." I was wrong. They handle *everything*.

The Android Asset Links file (`assetlinks.json`) on `ulink.prod.ddmprod` lists the Android packages:

```
com.cardfree.android.dunkindonuts.DEV
com.cardfree.android.dunkindonuts.UAT
```

CardFree isn't just the payment vendor. CardFree **builds the entire Dunkin' mobile app** — iOS and Android. All environments. One signing key across DEV and UAT. The app in your pocket that says "Dunkin'" was made by a company called CardFree. The name "Dunkin' Brands" is on the certs but CardFree is on the code.

### Branch.io Leaks Its Own Kubernetes

I probed the Branch.io smart link and it returned HTTP 405 with these headers:

```
server: istio-envoy
x-envoy-decorator-operation: inboarder.links-inboarder.svc.cluster.local:80/*
```

That's an Istio service mesh on Kubernetes. The internal service is called `inboarder` in a namespace called `links-inboarder`. Branch.io's infrastructure is leaking its own service topology through response headers. The deep linking company has a shallow header policy.

### 931 Certificate Transparency Entries

I queried `crt.sh` for `%.dunkinbrands.com` and got back **931 certificate entries**. Nine hundred and thirty-one. This is the pre-Inspire Brands corporate infrastructure, fossilized in certificate transparency logs:

- **`citrix.dunkinbrands.com`** — Citrix remote access
- **`sslvpn.dunkinbrands.com`** (and sslvpn2) — SSL VPN
- **`vdi.dunkinbrands.com`** — Virtual Desktop Infrastructure
- **`xen.dunkinbrands.com`** — Xen virtualization (vintage!)
- **`quickplace.dunkinbrands.com`**, **`quickr.dunkinbrands.com`**, **`inotes.dunkinbrands.com`** — IBM collaboration stack. QuickPlace was discontinued in 2007. The cert was issued anyway.
- **`smartsolve.dunkinbrands.com`** — SmartSolve EQMS (quality management)
- **`genesisproduction.dunkinbrands.com`** — an internal platform called "Genesis"
- **`rbos.dunkinbrands.com`** — RBOS. Restaurant Business Operating System? Nobody will confirm or deny.
- **`smartphone.dunkinbrands.com`** (and smartphone2, smartphone3) — three separate mobile device management endpoints

And then, buried in the entries: **`terry.ursino@dunkinbrands.com`**. Someone's email address. In a certificate Common Name. Submitted to public Certificate Transparency logs. Forever.

Hi Terry. I hope you're doing well. Your email is in the blockchain of certificates now and there's nothing anyone can do about it.

### The u/dunkin Reddit Account

Created **October 18, 2018** — right when Dunkin' dropped "Donuts" from the name. The account was born with the rebrand. It has 62 link karma and 67 comment karma after 7+ years. The promoted posts don't appear in Reddit's public API because they're served through the ad system, not the user's post history. It's a ghost account that only exists to run paid campaigns.

It is verified. It is a moderator. It has almost no karma. It pretends a toddler typed on its phone to sell you a drink. It is `u/dunkin`.

### Methodology

All probes ran inside containerized environments (`podman run --rm --dns 8.8.8.8 investigator`). DNS enumeration, HTTP redirect tracing, TLS certificate inspection, Wayback Machine CDX queries, Apple App Site Association file retrieval, Reddit public API, iTunes Search API, nmap port scanning. Zero exploitation, zero auth bypass, zero interaction with any service beyond reading what they publicly serve.

I just looked at what was already there. Dunkin' made it easy.

![claude reacting to the findings](memes/claude-holy-shit.png)

*My AI research assistant, upon discovering that Dunkin' and Baskin-Robbins are the same server.*

---

## Investigation Files
- **[GRAPH.md](investigations/dunkin/GRAPH.md)** — The serious version. 56 entities, 12 clusters, 21 anomalies. Structured for machines.
- **[Investigation directory](investigations/dunkin/)** — Evidence, artifacts, reproducible scripts.
- **[GRAPH.md (index)](GRAPH.md)** — Investigation index.

## Setup

```bash
podman build -t investigator -f Containerfile.investigator .
```
