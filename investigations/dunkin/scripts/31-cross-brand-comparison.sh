#!/bin/bash
# Cross-brand infrastructure comparison matrix
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/cross-brand-comparison-2026-04-13:/out:Z \
#   investigator bash /work/scripts/31-cross-brand-comparison.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== CROSS-BRAND INFRASTRUCTURE COMPARISON ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

BRANDS=(
  "dunkindonuts.com"
  "baskinrobbins.com"
  "arbys.com"
  "buffalowildwings.com"
  "sonicdrivein.com"
  "jimmyjohns.com"
)

# Build comparison data for each brand
for brand in "${BRANDS[@]}"; do
  short=$(echo "$brand" | cut -d. -f1)

  echo "========================================" | tee -a "$OUTDIR/results.txt"
  echo "BRAND: $brand" | tee -a "$OUTDIR/results.txt"
  echo "========================================" | tee -a "$OUTDIR/results.txt"

  # CDN Detection (from www CNAME chain)
  echo "  CDN:" | tee -a "$OUTDIR/results.txt"
  www_cname=$(dig +short "www.$brand" CNAME @8.8.8.8 2>/dev/null | head -1)
  if echo "$www_cname" | grep -qi "akamai\|edgekey\|edgesuite"; then
    echo "    Akamai ($www_cname)" | tee -a "$OUTDIR/results.txt"
  elif echo "$www_cname" | grep -qi "cloudfront"; then
    echo "    CloudFront ($www_cname)" | tee -a "$OUTDIR/results.txt"
  elif echo "$www_cname" | grep -qi "cloudflare"; then
    echo "    Cloudflare ($www_cname)" | tee -a "$OUTDIR/results.txt"
  elif echo "$www_cname" | grep -qi "fastly"; then
    echo "    Fastly ($www_cname)" | tee -a "$OUTDIR/results.txt"
  else
    echo "    Unknown/Direct (${www_cname:-no CNAME})" | tee -a "$OUTDIR/results.txt"
  fi

  # Cert Authority
  echo "  Cert Authority:" | tee -a "$OUTDIR/results.txt"
  issuer=$(timeout 10 openssl s_client -connect "www.$brand:443" -servername "www.$brand" </dev/null 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null)
  echo "    $issuer" | tee -a "$OUTDIR/results.txt"

  # SAN count
  san_count=$(timeout 10 openssl s_client -connect "www.$brand:443" -servername "www.$brand" </dev/null 2>/dev/null | openssl x509 -noout -ext subjectAltName 2>/dev/null | tr ',' '\n' | grep -c DNS || echo 0)
  echo "  SAN Count: $san_count" | tee -a "$OUTDIR/results.txt"

  # DNS Provider (NS records)
  echo "  DNS Provider:" | tee -a "$OUTDIR/results.txt"
  ns=$(dig +short "$brand" NS @8.8.8.8 2>/dev/null | head -2 | tr '\n' ', ' | sed 's/, $//')
  if echo "$ns" | grep -qi "awsdns"; then
    echo "    AWS Route 53 ($ns)" | tee -a "$OUTDIR/results.txt"
  elif echo "$ns" | grep -qi "cloudflare"; then
    echo "    Cloudflare ($ns)" | tee -a "$OUTDIR/results.txt"
  elif echo "$ns" | grep -qi "ultradns"; then
    echo "    UltraDNS ($ns)" | tee -a "$OUTDIR/results.txt"
  elif echo "$ns" | grep -qi "dnsimple"; then
    echo "    DNSimple ($ns)" | tee -a "$OUTDIR/results.txt"
  else
    echo "    $ns" | tee -a "$OUTDIR/results.txt"
  fi

  # Ordering Vendor (order.* CNAME)
  echo "  Ordering Vendor:" | tee -a "$OUTDIR/results.txt"
  order_cname=$(dig +short "order.$brand" CNAME @8.8.8.8 2>/dev/null | head -1)
  order_a=$(dig +short "order.$brand" A @8.8.8.8 2>/dev/null | head -1)
  if echo "$order_cname" | grep -qi "olo"; then
    echo "    OLO ($order_cname)" | tee -a "$OUTDIR/results.txt"
  elif echo "$order_cname" | grep -qi "tillster"; then
    echo "    Tillster ($order_cname)" | tee -a "$OUTDIR/results.txt"
  elif echo "$order_cname" | grep -qi "paytronix"; then
    echo "    Paytronix ($order_cname)" | tee -a "$OUTDIR/results.txt"
  elif [ -n "$order_cname" ]; then
    echo "    Unknown ($order_cname)" | tee -a "$OUTDIR/results.txt"
  elif [ -n "$order_a" ]; then
    echo "    Direct IP ($order_a)" | tee -a "$OUTDIR/results.txt"
  else
    echo "    No order subdomain" | tee -a "$OUTDIR/results.txt"
  fi

  # Cloud Provider (root A records)
  echo "  Cloud Provider:" | tee -a "$OUTDIR/results.txt"
  root_a=$(dig +short "$brand" A @8.8.8.8 2>/dev/null | head -1)
  if [ -n "$root_a" ]; then
    # Quick ASN lookup via whois
    org=$(whois "$root_a" 2>/dev/null | grep -i 'OrgName' | head -1 | sed 's/.*: *//')
    echo "    $root_a (${org:-unknown})" | tee -a "$OUTDIR/results.txt"
  else
    echo "    No A record" | tee -a "$OUTDIR/results.txt"
  fi

  # Email vendor (MX)
  echo "  Email (MX):" | tee -a "$OUTDIR/results.txt"
  mx=$(dig +short "$brand" MX @8.8.8.8 2>/dev/null | head -2)
  if echo "$mx" | grep -qi "google\|gmail"; then
    echo "    Google Workspace" | tee -a "$OUTDIR/results.txt"
  elif echo "$mx" | grep -qi "outlook\|microsoft"; then
    echo "    Microsoft 365" | tee -a "$OUTDIR/results.txt"
  elif echo "$mx" | grep -qi "pphosted\|proofpoint"; then
    echo "    Proofpoint" | tee -a "$OUTDIR/results.txt"
  elif echo "$mx" | grep -qi "mimecast"; then
    echo "    Mimecast" | tee -a "$OUTDIR/results.txt"
  else
    echo "    $mx" | tee -a "$OUTDIR/results.txt"
  fi

  # DMARC policy
  echo "  DMARC Policy:" | tee -a "$OUTDIR/results.txt"
  dmarc=$(dig +short "_dmarc.$brand" TXT @8.8.8.8 2>/dev/null | head -1)
  echo "    $dmarc" | tee -a "$OUTDIR/results.txt"

  # Server header
  echo "  Server Header:" | tee -a "$OUTDIR/results.txt"
  server=$(curl -sk --max-time 8 -I "https://www.$brand/" 2>/dev/null | grep -i '^server:' | head -1 | tr -d '\r')
  echo "    ${server:-none}" | tee -a "$OUTDIR/results.txt"

  # Shared A records check (compare to dunkindonuts.com)
  if [ "$brand" != "dunkindonuts.com" ]; then
    dunkin_a=$(dig +short "dunkindonuts.com" A @8.8.8.8 2>/dev/null | sort | tr '\n' ',')
    brand_a=$(dig +short "$brand" A @8.8.8.8 2>/dev/null | sort | tr '\n' ',')
    if [ "$dunkin_a" = "$brand_a" ] && [ -n "$dunkin_a" ]; then
      echo "  ** SHARES A RECORDS WITH DUNKINDONUTS.COM **" | tee -a "$OUTDIR/results.txt"
    fi
  fi

  echo "" | tee -a "$OUTDIR/results.txt"
done

echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
echo "Completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
