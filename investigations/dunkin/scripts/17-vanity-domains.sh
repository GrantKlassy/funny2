#!/bin/bash
# Vanity domain mapping: full DNS, redirect chains, TLS certs
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/vanity-domains-2026-04-13:/out:Z \
#   investigator bash /work/scripts/17-vanity-domains.sh
set -euo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== VANITY DOMAIN MAPPING ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

DOMAINS=(
  "dunkinrewards.com" "www.dunkinrewards.com"
  "dunkinemail.com" "www.dunkinemail.com"
  "ddperks.com" "www.ddperks.com"
  "dunkinperks.com" "www.dunkinperks.com"
  "ddglobalfranchising.com" "www.ddglobalfranchising.com"
  "dunkinnation.com" "www.dunkinnation.com"
  "dunkinrun.com" "www.dunkinrun.com"
  "dunkinfranchising.com" "www.dunkinfranchising.com"
  "baskinrobbinsfranchising.com" "www.baskinrobbinsfranchising.com"
  "brglobalfranchising.com" "www.brglobalfranchising.com"
)

# === FULL DNS ===
echo "--- DNS Resolution ---" | tee -a "$OUTDIR/results.txt"
for domain in "${DOMAINS[@]}"; do
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
  ns=$(dig +short "$domain" NS @8.8.8.8 2>/dev/null | head -2 | tr '\n' ',' | sed 's/,$//')
  mx=$(dig +short "$domain" MX @8.8.8.8 2>/dev/null | head -2 | tr '\n' ',' | sed 's/,$//')
  echo "$domain" | tee -a "$OUTDIR/results.txt"
  echo "  A: ${a:-none}  CNAME: ${cname:-none}" | tee -a "$OUTDIR/results.txt"
  echo "  NS: ${ns:-none}  MX: ${mx:-none}" | tee -a "$OUTDIR/results.txt"
done

# === REDIRECT CHAIN TRACING ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Redirect Chains ---" | tee -a "$OUTDIR/results.txt"
for domain in "${DOMAINS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> https://$domain/" | tee -a "$OUTDIR/results.txt"
  curl -sIL --max-time 15 "https://$domain/" 2>/dev/null | grep -iE "^(HTTP|location:)" | tee -a "$OUTDIR/results.txt" || true

  # Also try HTTP (non-SSL) — some may behave differently
  echo ">> http://$domain/" | tee -a "$OUTDIR/results.txt"
  curl -sIL --max-time 15 "http://$domain/" 2>/dev/null | grep -iE "^(HTTP|location:)" | tee -a "$OUTDIR/results.txt" || true
done

# === TLS CERTS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- TLS Certificates ---" | tee -a "$OUTDIR/results.txt"

# Only check base domains (not www variants — they'll share)
BASE_DOMAINS=("dunkinrewards.com" "dunkinemail.com" "ddperks.com" "dunkinperks.com" "ddglobalfranchising.com" "dunkinnation.com" "dunkinrun.com" "dunkinfranchising.com" "baskinrobbinsfranchising.com" "brglobalfranchising.com")
for domain in "${BASE_DOMAINS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> $domain" | tee -a "$OUTDIR/results.txt"
  echo | timeout 10 openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -subject -issuer -ext subjectAltName 2>/dev/null | head -15 | tee -a "$OUTDIR/results.txt" || echo "  TLS failed" | tee -a "$OUTDIR/results.txt"
done

# === CHECK FOR OWN CONTENT (not pure redirects) ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Content Check (non-redirect responses) ---" | tee -a "$OUTDIR/results.txt"
for domain in "${DOMAINS[@]}"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "https://$domain/" 2>/dev/null || echo "FAIL")
  if [ "$code" = "200" ]; then
    echo "" | tee -a "$OUTDIR/results.txt"
    echo ">> $domain serves content (200):" | tee -a "$OUTDIR/results.txt"
    curl -s --max-time 8 "https://$domain/" 2>/dev/null | head -30 | tee -a "$OUTDIR/results.txt"
  fi
done

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
