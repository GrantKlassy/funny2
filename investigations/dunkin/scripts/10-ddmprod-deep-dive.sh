#!/bin/bash
# Deep dive: ddmprod preprod services, CT logs, Branch.io, OLO, vendor stack
# Container: podman run --rm --dns 8.8.8.8 investigator bash -c '...'
set -euo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== DDMPROD DEEP DIVE + VENDOR STACK ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# === DDMPROD PREPROD SERVICES ===
echo "--- ddmprod Preprod Resolution ---" | tee -a "$OUTDIR/results.txt"
for sub in "ulink.preprod" "mapi-dun.preprod" "ode.preprod" "swi.preprod" "dun-assets.preprod" "cloud-preprod" "k.preprod"; do
  full="$sub.ddmprod.dunkindonuts.com"
  a=$(dig +short "$full" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$full" CNAME @8.8.8.8 2>/dev/null | head -1)
  if [ -n "$cname" ]; then
    echo "HIT  $full → CNAME → $cname → A: $a" | tee -a "$OUTDIR/results.txt"
  elif [ -n "$a" ]; then
    echo "HIT  $full → A: $a" | tee -a "$OUTDIR/results.txt"
  else
    echo "MISS $full" | tee -a "$OUTDIR/results.txt"
  fi
done

# Check for more ddmprod subdomains via additional guessing
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- ddmprod Subdomain Bruteforce ---" | tee -a "$OUTDIR/results.txt"
for sub in "api" "auth" "admin" "config" "gateway" "push" "notification" "analytics" "loyalty" "menu" "store" "payment" "wallet" "reward" "coupon" "scan" "qr" "geo" "location" "cdn" "img" "static" "web" "app" "mobile" "mapi-br" "mapi" "br-assets"; do
  for env in "prod" "preprod"; do
    full="$sub.$env.ddmprod.dunkindonuts.com"
    a=$(dig +short "$full" A @8.8.8.8 2>/dev/null | head -1)
    cname=$(dig +short "$full" CNAME @8.8.8.8 2>/dev/null | head -1)
    if [ -n "$cname" ] || [ -n "$a" ]; then
      echo "HIT  $full → ${cname:-$a}" | tee -a "$OUTDIR/results.txt"
    fi
  done
done

# === CT LOGS (crt.sh) ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- CT Logs (crt.sh) ---" | tee -a "$OUTDIR/results.txt"

# Search for ddmprod certs
echo ">> crt.sh query: %.ddmprod.dunkindonuts.com" | tee -a "$OUTDIR/results.txt"
crt_ddmprod=$(curl -s --max-time 30 "https://crt.sh/?q=%25.ddmprod.dunkindonuts.com&output=json" 2>/dev/null || echo "TIMEOUT")
if [ "$crt_ddmprod" != "TIMEOUT" ] && echo "$crt_ddmprod" | jq . >/dev/null 2>&1; then
  echo "$crt_ddmprod" | jq -r '.[].name_value' 2>/dev/null | sort -u | tee -a "$OUTDIR/results.txt"
  echo "  ($(echo "$crt_ddmprod" | jq length) cert entries)" | tee -a "$OUTDIR/results.txt"
else
  echo "  crt.sh query failed or timed out" | tee -a "$OUTDIR/results.txt"
fi

# Search for dunkinbrands.com certs
echo "" | tee -a "$OUTDIR/results.txt"
echo ">> crt.sh query: %.dunkinbrands.com" | tee -a "$OUTDIR/results.txt"
crt_brands=$(curl -s --max-time 30 "https://crt.sh/?q=%25.dunkinbrands.com&output=json" 2>/dev/null || echo "TIMEOUT")
if [ "$crt_brands" != "TIMEOUT" ] && echo "$crt_brands" | jq . >/dev/null 2>&1; then
  echo "$crt_brands" | jq -r '.[].name_value' 2>/dev/null | sort -u | tee -a "$OUTDIR/results.txt"
  echo "  ($(echo "$crt_brands" | jq length) cert entries)" | tee -a "$OUTDIR/results.txt"
else
  echo "  crt.sh query failed or timed out" | tee -a "$OUTDIR/results.txt"
fi

# === BRANCH.IO SMART LINK ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Branch.io Smart Link Inspection ---" | tee -a "$OUTDIR/results.txt"

# Probe the smart link itself
echo ">> dunkin.smart.link (DNS)" | tee -a "$OUTDIR/results.txt"
dig +short "dunkin.smart.link" A @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
dig +short "dunkin.smart.link" CNAME @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

# Follow the smart link redirect chain
echo ">> Smart link redirect chain (f6iexb4x5)" | tee -a "$OUTDIR/results.txt"
curl -sIL --max-time 10 "https://dunkin.smart.link/f6iexb4x5" 2>/dev/null | grep -E "^(HTTP|location|Location|server|Server|x-)" | tee -a "$OUTDIR/results.txt"

# Check Branch.io app link config
echo ">> dunkin.app.link (Branch alternate)" | tee -a "$OUTDIR/results.txt"
dig +short "dunkin.app.link" A @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
dig +short "dunkin.app.link" CNAME @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
curl -sI --max-time 10 "https://dunkin.app.link/" 2>/dev/null | head -15 | tee -a "$OUTDIR/results.txt"

# Check for Branch dashboard/config exposed
echo ">> Branch open graph metadata" | tee -a "$OUTDIR/results.txt"
curl -sL --max-time 10 "https://dunkin.smart.link/f6iexb4x5" 2>/dev/null | grep -oP '(branch_key|data-branch|og:|branch\.io)[^"]*"[^"]*"' | head -20 | tee -a "$OUTDIR/results.txt"

# === OLO ORDERING PLATFORM ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- OLO Ordering Platform ---" | tee -a "$OUTDIR/results.txt"

echo ">> order.dunkindonuts.com headers" | tee -a "$OUTDIR/results.txt"
curl -sI --max-time 10 "https://order.dunkindonuts.com/" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"

echo ">> whitelabel.olo.com cert" | tee -a "$OUTDIR/results.txt"
echo | timeout 10 openssl s_client -connect "whitelabel.olo.com:443" -servername "order.dunkindonuts.com" 2>/dev/null | openssl x509 -noout -subject -issuer -text 2>/dev/null | grep -E "(Subject:|Issuer:|DNS:)" | head -20 | tee -a "$OUTDIR/results.txt"

# Check if other Inspire brands use OLO
echo ">> Inspire brands OLO check" | tee -a "$OUTDIR/results.txt"
for brand_domain in "arbys.com" "buffalowildwings.com" "sonicdrivein.com" "jimmyjohns.com"; do
  order_cname=$(dig +short "order.$brand_domain" CNAME @8.8.8.8 2>/dev/null | head -1)
  if [ -n "$order_cname" ]; then
    echo "  order.$brand_domain → $order_cname" | tee -a "$OUTDIR/results.txt"
  else
    echo "  order.$brand_domain — no CNAME" | tee -a "$OUTDIR/results.txt"
  fi
done

# === WAYBACK — deeper ddmprod crawl ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Wayback Machine — Expanded ddmprod History ---" | tee -a "$OUTDIR/results.txt"

# Check all ddmprod services in Wayback
for sub in "mapi-dun.prod" "ode.prod" "swi.prod" "dun-assets.prod" "cloud-preprod" "k.prod"; do
  full="$sub.ddmprod.dunkindonuts.com"
  echo ">> Wayback: $full" | tee -a "$OUTDIR/results.txt"
  wb=$(curl -s --max-time 15 "https://web.archive.org/cdx/search/cdx?url=$full/*&output=json&fl=timestamp,original,statuscode,mimetype&limit=20" 2>/dev/null || echo "TIMEOUT")
  if [ "$wb" != "TIMEOUT" ] && echo "$wb" | jq . >/dev/null 2>&1; then
    echo "$wb" | jq -r '.[] | @tsv' 2>/dev/null | tail -20 | tee -a "$OUTDIR/results.txt"
  else
    echo "  No results or timeout" | tee -a "$OUTDIR/results.txt"
  fi
  echo "" | tee -a "$OUTDIR/results.txt"
done

# === DUNKIN APP — Android manifest check ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Dunkin Android Asset Links ---" | tee -a "$OUTDIR/results.txt"
curl -sL --max-time 10 "https://ulink.prod.ddmprod.dunkindonuts.com/.well-known/assetlinks.json" 2>/dev/null | jq . 2>/dev/null | head -40 | tee -a "$OUTDIR/results.txt"

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
