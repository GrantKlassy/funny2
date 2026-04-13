#!/bin/bash
# Probe all 44 SANs from the www.dunkindonuts.com cert + dunkin brand domains
# Container: podman run --rm --dns 8.8.8.8 investigator bash -c '...'
set -euo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== WWW CERT SAN RESOLUTION + DUNKIN BRAND DOMAINS ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# All SANs from the www cert + brand domains from root cert
DOMAINS=(
  # www cert SANs — SDLC environments
  "dev2.dunkindonuts.com"
  "qa.dunkindonuts.com"
  "qa2.dunkindonuts.com"
  "staging.dunkindonuts.com"
  "staging3.dunkindonuts.com"
  "uat.dunkindonuts.com"
  # www cert SANs — SSO
  "ssoprd.dunkindonuts.com"
  "ssostg.dunkindonuts.com"
  "social-ssoprd.dunkindonuts.com"
  "social-ssopreprod.dunkindonuts.com"
  "social-ssostg.dunkindonuts.com"
  # www cert SANs — Menu/Pricing
  "menu-pricing-prd.dunkindonuts.com"
  "menu-pricing-prd1.dunkindonuts.com"
  "menu-pricing-stg.dunkindonuts.com"
  # www cert SANs — Loyalty/Other
  "loyalty.dunkindonuts.com"
  "star.dunkinbrands.com"
  "afm.dunkinbrands.com"
  "fps.dunkinbrands.com"
  # www cert SANs — QR Menu
  "qrmenu.dunkinbrands.com"
  "qrmenu-stg.dunkinbrands.com"
  # www cert SANs — Franchisee
  "franchiseecentral.dunkinbrands.com"
  # www cert SANs — Cross-brand
  "www.baskinrobbins.com"
  "www2.baskinrobbins.com"
  "staging.baskinrobbins.com"
  "staging2.baskinrobbins.com"
  "qa.baskinrobbins.com"
  "www.brglobalfranchising.com"
  # www cert SANs — Misc
  "dunkinnation.com"
  "dunkinrewards.com"
  "wsvc.dunkinrun.com"
  "www.ddperks.com"
  "www.dunkinemail.com"
  # Root cert domains
  "dunkinrun.com"
  "dunkinemail.com"
  "dunkinfranchising.com"
  "ddglobalfranchising.com"
  "ddperks.com"
  "baskinrobbinsfranchising.com"
  "dunkinperks.com"
  # dunkinbrands.com root
  "dunkinbrands.com"
  "www.dunkinbrands.com"
)

echo "--- DNS Resolution ---" | tee -a "$OUTDIR/results.txt"
for domain in "${DOMAINS[@]}"; do
  a_records=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)

  if [ -n "$cname" ]; then
    echo "HIT  $domain → CNAME → $cname → A: $a_records" | tee -a "$OUTDIR/results.txt"
  elif [ -n "$a_records" ]; then
    echo "HIT  $domain → A: $a_records" | tee -a "$OUTDIR/results.txt"
  else
    echo "MISS $domain" | tee -a "$OUTDIR/results.txt"
  fi
done

echo "" | tee -a "$OUTDIR/results.txt"
echo "--- HTTP Probing (live domains only) ---" | tee -a "$OUTDIR/results.txt"

for domain in "${DOMAINS[@]}"; do
  a_records=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -1)
  if [ -z "$a_records" ]; then
    continue
  fi

  http_code=$(curl -sL -o /dev/null -w '%{http_code}' --max-time 8 "https://$domain/" 2>/dev/null || echo "FAIL")
  redirect=$(curl -sI --max-time 8 "https://$domain/" 2>/dev/null | grep -i "^location:" | head -1 | tr -d '\r' || true)
  server=$(curl -sI --max-time 8 "https://$domain/" 2>/dev/null | grep -i "^server:" | head -1 | tr -d '\r' || true)
  title=$(curl -sL --max-time 8 "https://$domain/" 2>/dev/null | grep -oP '(?<=<title>).*?(?=</title>)' | head -1 || true)

  echo "$domain → HTTP $http_code | ${server:-no server header} | title: ${title:-none} | ${redirect:-no redirect}" | tee -a "$OUTDIR/results.txt"
done

echo "" | tee -a "$OUTDIR/results.txt"

# Special probes for interesting domains
echo "--- Deep Probes ---" | tee -a "$OUTDIR/results.txt"

# Franchisee portal
echo ">> franchiseecentral.dunkinbrands.com" | tee -a "$OUTDIR/results.txt"
curl -sI --max-time 10 "https://franchiseecentral.dunkinbrands.com/" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"

# Menu pricing API
echo ">> menu-pricing-prd.dunkindonuts.com" | tee -a "$OUTDIR/results.txt"
curl -sI --max-time 10 "https://menu-pricing-prd.dunkindonuts.com/" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"
curl -sI --max-time 10 "https://menu-pricing-prd.dunkindonuts.com/api" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"

# SSO
echo ">> ssoprd.dunkindonuts.com" | tee -a "$OUTDIR/results.txt"
curl -sI --max-time 10 "https://ssoprd.dunkindonuts.com/" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"

# Loyalty
echo ">> loyalty.dunkindonuts.com" | tee -a "$OUTDIR/results.txt"
curl -sI --max-time 10 "https://loyalty.dunkindonuts.com/" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"

# QR Menu
echo ">> qrmenu.dunkinbrands.com" | tee -a "$OUTDIR/results.txt"
curl -sI --max-time 10 "https://qrmenu.dunkinbrands.com/" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"

# dunkinrun.com (the campaign domain)
echo ">> dunkinrun.com" | tee -a "$OUTDIR/results.txt"
curl -sIL --max-time 10 "https://dunkinrun.com/" 2>/dev/null | head -30 | tee -a "$OUTDIR/results.txt"

# Baskin Robbins
echo ">> www.baskinrobbins.com AASA" | tee -a "$OUTDIR/results.txt"
curl -sL --max-time 10 "https://www.baskinrobbins.com/.well-known/apple-app-site-association" 2>/dev/null | jq . 2>/dev/null | head -40 | tee -a "$OUTDIR/results.txt"

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
