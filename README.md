<div align="center">

# :doughnut: I Reverse-Engineered Dunkin's Entire Digital Infrastructure Because Their Reddit Ad Annoyed Me :doughnut:

**33 probe scripts. 77 entities. 29 vendors. 19 dead services. 1 load-bearing typo.**

**All because a fake toddler tried to sell me a mango drink.**

[![Explore the Network Graph](https://img.shields.io/badge/EXPLORE_THE_NETWORK_GRAPH-ff6600?style=for-the-badge&logo=d3dotjs&logoColor=white)](https://grantklassy.github.io/funny2/investigations/dunkin/graph/network-visualization.html)
[![Full Investigation](https://img.shields.io/badge/FULL_WRITEUP-333333?style=for-the-badge&logo=markdown&logoColor=white)](investigations/dunkin/README.md)
[![Graph Data](https://img.shields.io/badge/GRAPH.md-222222?style=for-the-badge&logo=graphql&logoColor=white)](investigations/dunkin/GRAPH.md)

</div>

---

## The Crime

| The ad | The "toddler" | The landing page |
|:---:|:---:|:---:|
| <img src="investigations/dunkin/intake-2026-04-13/dunkin1.jpg" width="100%"> | <img src="investigations/dunkin/intake-2026-04-13/dunkin2.jpg" width="100%"> | <img src="investigations/dunkin/intake-2026-04-13/dunkin3.jpg" width="100%"> |

Read the middle one. A corporate account — verified, promoted, paid money — posted this:

```
Wjkhsgjkhdgkhkjfhgdfgdogihdgcatmomdfgddgjkk
kidogsyjkdffkkjkddadadadadadadadamommmmmmmdf
d7766Vvvqg8888
AAAAAAAAAaaaaaasssvIFFGHF7ghfh88
```

> *"Sorry, toddler had my phone."*

No. Your toddler did not have your phone. Your **copywriter** had your phone. I ran the gibberish through keyboard distribution analysis:

| Row | Toddler would hit | Actual |
|---|---|---|
| Top row (qwerty) | ~33% | **10%** |
| **Home row (asdf)** | ~33% | **77%** :skull: |
| Bottom row (zxcv) | ~33% | **12%** |

**Seventy-seven percent home row.** That's a grown adult wiggling their fingers on asdfghjkl. With strategically embedded words: `cat`, `dog`, `kid`, `mom`, `dad`, `dada`. The toddler is a psyop.

I clicked the ad. The URL was `ulink.prod.ddmprod.dunkindonuts.com` — a subdomain four levels deep leaking internal environment naming. I opened a container and started digging.

I didn't stop for three waves.

---

## :rotating_light: The Findings :rotating_light:

### :abc: The Load-Bearing Typo

I found Dunkin's **Restaurant Administration Portal** — an internal tool serving 18,000+ franchise locations. It has a one-time-password login flow. The API endpoint is:

> ### `/User/GenrateOTPForUser`

<kbd>G</kbd><kbd>e</kbd><kbd>n</kbd><kbd>r</kbd><kbd>a</kbd><kbd>t</kbd><kbd>e</kbd>

Not "Generate." ***Genrate.***

> [!CAUTION]
> This is a production ASP.NET Core application serving 18,000+ Dunkin' locations. The typo is baked into every franchise operator's cached JavaScript. **They can never fix it.** The typo is load-bearing. It will outlive us all.

---

### :speech_balloon: Sonic Put a Slack Message in DNS

I enumerated DNS TXT records for all six Inspire Brands restaurant chains. Then I got to Sonic Drive-In. One of their 33 TXT records:

```dns
"[6:20 PM] Nelson, Brandi     atlassian-domain-verification=ePV5FzMQVHW78z2fSa9NUn8GwnrxUxwaPVUjsYP4bWfQliM21X7G4LMCvG65MgvF"
```

> [!WARNING]
> That is a **Slack message pasted into a DNS record.** Including the timestamp. Including the sender's name. Someone copied the verification string from chat and pasted the **entire message** into production DNS.

Every DNS resolver on the internet knows Brandi Nelson sent that string at 6:20 PM. She is part of the global DNS infrastructure now. They added a clean copy later. **They never deleted the Brandi version.** Both coexist — two copies of the same key, one wearing Brandi Nelson's name like a digital tramp stamp.

---

### :name_badge: Somebody Else's Certificate

`wsapi.dunkinbrands.com` — Dunkin's "Web Service API" — returns headers saying `x-theorem-auth: nil`. Theorem? I pulled the TLS cert:

```
subject=CN=api-test.theoremlp.com
```

> [!IMPORTANT]
> Dunkin's subdomain is serving **a completely different company's test certificate.** Someone at Theorem LP is still renewing it. On Dunkin's infrastructure. Nobody has noticed.

---

### :ghost: The Haunted EC2 Instance

`swagger.ddmdev.dunkindonuts.com` — a bare EC2 instance, no CDN, naked on the internet. Every other Dunkin' service hides behind Akamai or Cloudflare. I built an entire probe script for this one.

It's a **Swagger Editor.** Not API docs. An *editor.* 3,540 bytes of HTML. `Last-Modified: December 23, 2019.`

> [!NOTE]
> Some developer spun up nginx on EC2 five days before 2020 and walked away. **Six years ago.** The instance survived a pandemic, a parent company acquisition, and three generations of infrastructure. It serves no purpose. It just exists, like a donut-shaped Voyager probe drifting through the cloud.

---

### :flying_saucer: SWI: Area 51

The mobile platform has a service called **SWI**. It's LIVE in production, preprod, dev, and qa. Six environments. Actively maintained. I threw **35 paths** at it — APIs, health checks, Swagger, login, auth, webhook, push, `/swi`, `/SWI`.

**Every. Single. Path. Returns. 404.**

Ruby on Rails. Behind Akamai. Shares a TLS cert with the Mobile API and the Order Delivery Engine. A first-class citizen of the platform that does *nothing anyone can see from outside.* Six environments. 35 paths. Zero answers. SWI remains this investigation's Area 51.

---

### :coffin: The Redirect Graveyard

Dunkin' owns vanity domains from campaigns past. They age like forgotten donuts.

| Domain | Registered | Status |
|--------|-----------|--------|
| `dnkn.com` | **2003** | TLS cert **expired since Sep 2022.** Three and a half years. Still redirecting. Nobody noticed. |
| `dunkinnation.com` | — | **Infinite redirect loop.** Root → www → dead. A donut-shaped ouroboros. |
| `dunkinemail.com` | — | **Five redirects** through three rebrands of loyalty programs → lands on **403 Forbidden.** You can't sign up for email via the email domain. |
| `lsmnow.com` | **2004** | Redirects to an **F5 BIG-IP VPN login.** Twenty-two years old. MX points to "Flair Promo." The portal is a fossil. The DNS is eternal. |

---

### :performing_arts: The Dead Sweepstakes Running as "SSO Production"

The endpoint named `ssoprd` — "SSO Production" — is actually a **DD Perks "Sip. Peel. Win Sweepstakes" login page.**

The sweepstakes is long over. The login page is still there. The production SSO endpoint is a dead sweepstakes.

Meanwhile `auth0-stg.dunkindonuts.com` exists because someone proposed Auth0 at a meeting once. The DNS record is their legacy. Three generations of auth, one is a dead sweepstakes, one is a meeting that became a DNS record. This is enterprise software.

---

### :ice_cream: Baskin-Robbins Is Literally Dunkin'

`baskinrobbins.com` resolves to the **exact same IP addresses** as `dunkindonuts.com`. Same cert. Same nameservers. Same box. You request ice cream and the donut server goes *"oh, different door."*

---

### :iphone: CardFree Runs Everything

The Dunkin' app's Android package is `com.cardfree.android.dunkindonuts`. CardFree doesn't handle payments. **CardFree IS the app.** Every time you tap "Order Ahead" you're using a company you've never heard of. Dunkin' is a CardFree customer wearing a costume.

---

### :email: One Pipe, Seven Chains

All seven Inspire Brands — Dunkin', Baskin-Robbins, Arby's, Buffalo Wild Wings, Sonic, Jimmy John's, and the parent company — use **identical email infrastructure.** Same Proofpoint. Same M365. Same DMARC. 44,000+ locations, one pipe.

The KnowBe4 phishing training token is identical across Arby's, BWW, and Sonic. Hack the phishing training for one, hack it for three.

---

### :school: Bakery Equipment Training on Adobe Experience Manager

There is a corporate learning management system, running on **Adobe Experience Manager**, behind CloudFront, registered to Inspire Brands of Sandy Springs, Georgia, and it has a course about **bakery equipment.** Franchisees log in with Okta, navigate the "Dunkin Learning Path," and learn about the equipment that makes the donuts. This is the circle of life.

---

<details>
<summary><h3>:briefcase: 29 Vendors to Sell Donuts (click to expand)</h3></summary>

| # | Vendor | What They Do |
|---|--------|-------------|
| 1 | Branch.io | Deep linking |
| 2 | OLO | Online ordering (Dunkin') |
| 3 | Tillster | Online ordering (Baskin-Robbins, different vendor!) |
| 4 | **CardFree** | **THE ENTIRE MOBILE APP** |
| 5 | CrunchTime | Restaurant ops *(the GenrateOTP people)* |
| 6 | Akamai | CDN + WAF |
| 7 | Cloudflare | CDN + DNS (other brands) |
| 8 | Proofpoint | Email security (all 7 brands) |
| 9 | Microsoft 365 | Corporate email (all 7 brands) |
| 10 | SendGrid | Transactional email |
| 11 | Salesforce MC | Email marketing |
| 12 | Mailchimp | More email (Sonic) |
| 13 | Mailgun | Even more email (Jimmy John's) |
| 14 | DigiCert | TLS certs |
| 15 | Let's Encrypt | TLS certs (dev) |
| 16 | AWS | Infrastructure |
| 17 | Azure | International site (just that one) |
| 18 | IBM Cloud | UAT (dead) |
| 19 | IPR Software | Investor relations |
| 20 | ServiceNow | Customer chat |
| 21 | Paradox AI | Recruiting |
| 22 | Adobe Analytics | Web analytics |
| 23 | Adobe AEM | Bakery equipment courses |
| 24 | Okta | SSO |
| 25 | KnowBe4 | Phishing training |
| 26 | **Theorem LP** | **??? (their cert is on Dunkin's domain)** |
| 27 | WeRecognize | Employee recognition |
| 28 | F5 Networks | Load balancing (legacy) |
| 29 | Flair Promo | Local Store Marketing (legacy) |

More vendors than menu items.

</details>

---

<div align="center">

## The Damage Report

| | |
|---|---|
| :bar_chart: **Probe scripts** | 33 |
| :globe_with_meridians: **Entities mapped** | 77 |
| :warning: **Anomalies** | 33 |
| :briefcase: **Vendors** | 29 |
| :headstone: **Dead services** | 19 |
| :arrows_counterclockwise: **Redirect loops** | 2 |
| :lock: **Expired certs in production** | 1 *(3.5 years)* |
| :speech_balloon: **Slack messages in DNS** | 1 |
| :abc: **Typos in production endpoints** | 1 |
| :ghost: **Forgotten EC2 instances** | 1 *(since 2019)* |
| :name_badge: **Wrong company's cert** | 1 |
| :email: **Brands sharing one email pipe** | 7 |

**This started because a Dunkin' ad pretended a toddler typed on a phone.**

</div>

---

![claude reacting to the findings](memes/claude-holy-shit.png)

*My AI research assistant, upon discovering that Dunkin' and Baskin-Robbins are the same server.*

---

<div align="center">

All probes ran in containers. Zero exploitation. Zero auth bypass. I just looked at what was already there.

[![Full Writeup](https://img.shields.io/badge/Full_Investigation-investigations/dunkin/README.md-blue?style=flat-square)](investigations/dunkin/README.md) [![Graph](https://img.shields.io/badge/GRAPH.md-77_entities,_33_anomalies-orange?style=flat-square)](investigations/dunkin/GRAPH.md) [![Scripts](https://img.shields.io/badge/Scripts-33_probe_scripts-green?style=flat-square)](investigations/dunkin/scripts/)

</div>
