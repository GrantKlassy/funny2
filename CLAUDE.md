# funny2

Investigation repo. Successor to `funny`.

## What This Is

A structured OSINT investigation workspace. Targets are scam networks, fraud infrastructure, and shady operators. The work is curl, dig, and patience — not hacking. We probe what's publicly exposed, document what we find, and build a graph.

## Rules

### 1. Containers Only

**All network-touching commands run inside Podman containers.** No exceptions. No "just a quick curl." No "let me check that DNS real fast." Everything goes through the investigator image.

```
podman run --rm --dns 8.8.8.8 investigator bash -c '...'
```

Why: Isolation. Reproducibility. The host machine never touches a target directly. If Claude runs `curl` or `dig` or `ncat` against an investigation target outside a container, that's a bug. Fix it.

The only acceptable host-side network commands are:
- `podman build` / `podman run` (managing containers)
- `git push` (pushing to GitHub)
- Anything targeting localhost or LAN

### 2. GRAPH.md Is the Source of Truth

Every investigation has a `GRAPH.md`. It's a structured knowledge graph — entities, edges, clusters, anomalies. Not prose. Not narrative. Structured data that a human or machine can parse.

When you discover something new, it goes in the graph FIRST. README and other docs are downstream of the graph. If it's not in the graph, it didn't happen.

### 3. Evidence Chain

All probe output goes to date-stamped artifact directories:
```
investigations/<name>/artifacts/<probe-name>-YYYY-MM-DD/
```

Artifacts are raw output. Don't clean them up, don't summarize them into the artifact file. The raw output IS the evidence. Summarize in GRAPH.md and README, point back to the artifact.

Prefer JSON output when the tool supports it. Fall back to plain text capture.

### 4. Reproducible Scripts

Every probe session that touches the network gets a script in `investigations/<name>/scripts/`. The script must:
- Run inside the container image
- Be re-runnable (idempotent where possible)
- Write output to the artifacts directory
- Not require interactive input

### 5. Investigation Pipeline

The standard recon pipeline, in order:
1. **DNS** — dig, subdomain enumeration, NS/MX/TXT/DKIM records
2. **HTTP** — curl headers, redirects, content hashing, API probing
3. **Certificates** — openssl s_client, crt.sh CT logs
4. **Ports** — ncat port sweep, banner grabbing
5. **Services** — deep interaction with exposed services (Redis, databases, admin panels)
6. **OSINT** — Wayback Machine CDX, whois, M365 tenant enum, GCS bucket listing, social media, regulatory filings

Each layer reveals targets for the next. Don't skip ahead.

### 6. What We Don't Do

- No exploitation. Finding an open Redis is recon. Writing to it is not.
- No credential stuffing, brute forcing, or auth bypass attempts.
- No social engineering or contacting targets/victims.
- No scraping PII. Focus on corporate entities, infrastructure, and operator identities that are already in public records (SEC filings, state registrations, FTC complaints).
- No storing secrets, API keys, or credentials found during recon. Document their EXISTENCE, not their VALUES.

### 7. Commit Discipline

- One commit per probe session or logical unit of work.
- Commit messages describe what was DISCOVERED, not what commands were run.
- No Co-Authored-By trailers (enforced by lefthook).
- Don't commit binary blobs over 500KB without good reason.

## Directory Structure

```
funny2/
├── CLAUDE.md                    # this file
├── GRAPH.md                     # repo-level graph index (links to per-investigation graphs)
├── README.md                    # public-facing overview
├── Containerfile.investigator   # the investigation container image
├── investigations/
│   └── <name>/
│       ├── GRAPH.md             # source of truth for this investigation
│       ├── README.md            # human-readable writeup
│       ├── scripts/             # reproducible probe scripts
│       └── artifacts/           # raw evidence, date-stamped subdirs
├── memes/                       # important context
├── Taskfile.yml
├── lefthook.yml
└── LICENSE.txt
```

## Container Image

The `investigator` image must include at minimum:
- curl, wget
- dig (bind-utils), whois
- ncat (nmap-ncat)
- openssl
- jq
- exiftool
- redis-cli (redis-tools)
- Node.js + npx (for js-beautify and similar)
- nmap (for service fingerprinting)
- strings, file, xxd (binary analysis)

Build: `podman build -t investigator -f Containerfile.investigator .`

## Tools That Worked (lessons from funny)

**Tier 1 — always reach for these first:**
- `curl` (HTTP probing, redirect chains, header inspection, API discovery)
- `dig` (DNS enumeration across multiple resolvers, record type sweeps)
- `crt.sh` CT log API (maps infrastructure the operator tried to hide)
- Wayback Machine CDX API (connects present to past, recovers dead pages)

**Tier 2 — high value when applicable:**
- `openssl s_client` (cert inspection, SNI tricks, comparing CF-fronted vs direct)
- `ncat -z` (port scanning) + banner grabbing
- JS bundle analysis (js-beautify + grep for URLs, brands, redirects)
- `whois` (registrar, dates, status)
- GCS/S3 bucket enumeration (publicly listable = jackpot)
- `redis-cli` / direct service interaction on exposed ports

**Tier 3 — supporting:**
- `exiftool` (EXIF metadata on images)
- M365 tenant enumeration (OpenID config endpoint)
- Zendesk/support portal API crawling
- `sha256sum` (content change detection between sessions)

## For Claude

When working in this repo:
- Read GRAPH.md before doing anything. Understand what's known.
- Propose new probes before running them. Say what you're going to do and why.
- After probing, update GRAPH.md FIRST, then README or other docs.
- If you find something unexpected, flag it. Don't bury it in output.
- Keep artifact filenames descriptive. `dns-recheck.json` not `output.json`.
- When writing scripts, use the established pattern: Podman container, --dns 8.8.8.8, structured output, date-stamped artifact dir.
- Never run network probes against investigation targets from the host. If you catch yourself about to do it, stop.
