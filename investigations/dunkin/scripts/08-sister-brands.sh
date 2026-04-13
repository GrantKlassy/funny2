#!/bin/bash
# Probe Inspire Brands sister brands for ddmprod-style patterns
# Container: podman run --rm --dns 8.8.8.8 investigator bash -c '...'
set -euo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== INSPIRE BRANDS SISTER BRAND INFRASTRUCTURE ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# Sister brands and their known domains
declare -A BRANDS=(
  ["arbys"]="arbys.com"
  ["buffalowildwings"]="buffalowildwings.com"
  ["sonicdrivein"]="sonicdrivein.com"
  ["baskinrobbins"]="baskinrobbins.com"
  ["jimmyjohns"]="jimmyjohns.com"
)

for brand in "${!BRANDS[@]}"; do
  domain="${BRANDS[$brand]}"
  echo "=== $brand ($domain) ===" | tee -a "$OUTDIR/results.txt"

  # Check for ddmprod-style subdomains
  for sub in "ulink.prod.ddmprod" "mapi-dun.prod.ddmprod" "ddmprod" "prod.ddmprod" "ulink.prod" "mapi.prod" "order"; do
    result=$(dig +short "$sub.$domain" @8.8.8.8 2>/dev/null || true)
    if [ -n "$result" ]; then
      echo "  HIT  $sub.$domain → $result" | tee -a "$OUTDIR/results.txt"
    else
      echo "  MISS $sub.$domain" | tee -a "$OUTDIR/results.txt"
    fi
  done

  # Check root domain DNS
  echo "  --- Root DNS ---" | tee -a "$OUTDIR/results.txt"
  dig +short "$domain" A @8.8.8.8 2>/dev/null | head -5 | while read -r ip; do
    echo "  A    $ip" | tee -a "$OUTDIR/results.txt"
  done
  dig +short "$domain" NS @8.8.8.8 2>/dev/null | head -5 | while read -r ns; do
    echo "  NS   $ns" | tee -a "$OUTDIR/results.txt"
  done
  dig +short "$domain" MX @8.8.8.8 2>/dev/null | head -5 | while read -r mx; do
    echo "  MX   $mx" | tee -a "$OUTDIR/results.txt"
  done

  # Check www cert SANs
  echo "  --- www TLS Cert ---" | tee -a "$OUTDIR/results.txt"
  cert_sans=$(echo | timeout 10 openssl s_client -connect "www.$domain:443" -servername "www.$domain" 2>/dev/null | openssl x509 -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1 | tr ',' '\n' | sed 's/DNS://g; s/^ *//' || true)
  san_count=$(echo "$cert_sans" | grep -c . || true)
  echo "  SANs: $san_count domains" | tee -a "$OUTDIR/results.txt"
  echo "$cert_sans" | head -20 | while read -r san; do
    echo "    $san" | tee -a "$OUTDIR/results.txt"
  done

  # Check cert issuer/org
  cert_info=$(echo | timeout 10 openssl s_client -connect "www.$domain:443" -servername "www.$domain" 2>/dev/null | openssl x509 -noout -subject -issuer 2>/dev/null || true)
  echo "$cert_info" | while read -r line; do
    echo "  $line" | tee -a "$OUTDIR/results.txt"
  done

  # Check AASA for app infrastructure
  echo "  --- Apple App Site Association ---" | tee -a "$OUTDIR/results.txt"
  aasa=$(curl -sL --max-time 10 "https://www.$domain/.well-known/apple-app-site-association" 2>/dev/null || true)
  if echo "$aasa" | jq . >/dev/null 2>&1; then
    echo "$aasa" | jq -c '.applinks.details[]? | {appID, paths}' 2>/dev/null | while read -r line; do
      echo "    $line" | tee -a "$OUTDIR/results.txt"
    done
    echo "$aasa" | jq -c '.activitycontinuation.apps[]?' 2>/dev/null | while read -r line; do
      echo "    activity: $line" | tee -a "$OUTDIR/results.txt"
    done
  else
    echo "    No valid AASA or not found" | tee -a "$OUTDIR/results.txt"
  fi

  # Check for order subdomain (OLO pattern)
  echo "  --- Order Subdomain ---" | tee -a "$OUTDIR/results.txt"
  order_cname=$(dig +short "order.$domain" CNAME @8.8.8.8 2>/dev/null || true)
  if [ -n "$order_cname" ]; then
    echo "  order.$domain → CNAME → $order_cname" | tee -a "$OUTDIR/results.txt"
  else
    echo "  order.$domain — no CNAME" | tee -a "$OUTDIR/results.txt"
  fi

  echo "" | tee -a "$OUTDIR/results.txt"
done

echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
