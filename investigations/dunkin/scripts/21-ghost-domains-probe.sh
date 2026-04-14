#!/bin/bash
# Ghost domains and vanity domain probing: clubdunkin, dnkn, lsmnow, etc.
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/ghost-domains-2026-04-13:/out:Z \
#   investigator bash /work/scripts/21-ghost-domains-probe.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== GHOST DOMAINS & VANITY DOMAIN PROBE ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# === NEW VANITY DOMAINS (discovered in cert SANs, never probed) ===
NEW_DOMAINS=(
  "clubdunkin.com"
  "www.clubdunkin.com"
  "dnkn.com"
  "www.dnkn.com"
  "lsmnow.com"
  "www.lsmnow.com"
  "dunkindonuts.co.uk"
  "www.dunkindonuts.co.uk"
)

echo "--- New Domain DNS ---" | tee -a "$OUTDIR/results.txt"
for domain in "${NEW_DOMAINS[@]}"; do
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
  ns=$(dig +short "$domain" NS @8.8.8.8 2>/dev/null | head -2 | tr '\n' ',' | sed 's/,$//')
  mx=$(dig +short "$domain" MX @8.8.8.8 2>/dev/null | head -2 | tr '\n' ',' | sed 's/,$//')
  txt=$(dig +short "$domain" TXT @8.8.8.8 2>/dev/null | head -3 | tr '\n' '|' | sed 's/|$//')
  echo "$domain" | tee -a "$OUTDIR/results.txt"
  echo "  A: ${a:-none}  CNAME: ${cname:-none}" | tee -a "$OUTDIR/results.txt"
  echo "  NS: ${ns:-none}  MX: ${mx:-none}" | tee -a "$OUTDIR/results.txt"
  echo "  TXT: ${txt:-none}" | tee -a "$OUTDIR/results.txt"
done

# === HTTP REDIRECT CHAINS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- HTTP Redirect Chains ---" | tee -a "$OUTDIR/results.txt"
for domain in "clubdunkin.com" "dnkn.com" "lsmnow.com" "dunkindonuts.co.uk"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "[$domain] HTTPS redirect chain:" | tee -a "$OUTDIR/results.txt"
  curl -sk --max-time 15 -L --max-redirs 10 -o /dev/null -w '%{url_effective} (final status: %{http_code}, redirects: %{num_redirects})' "https://$domain/" 2>/dev/null | tee -a "$OUTDIR/results.txt"
  echo "" | tee -a "$OUTDIR/results.txt"
  curl -sk --max-time 15 -L --max-redirs 10 -D "$OUTDIR/${domain}-redirect.headers" -o "$OUTDIR/${domain}-final.body" "https://$domain/" 2>/dev/null || echo "  HTTPS FAILED" | tee -a "$OUTDIR/results.txt"

  echo "[$domain] HTTP redirect chain:" | tee -a "$OUTDIR/results.txt"
  curl -s --max-time 15 -L --max-redirs 10 -o /dev/null -w '%{url_effective} (final status: %{http_code}, redirects: %{num_redirects})' "http://$domain/" 2>/dev/null | tee -a "$OUTDIR/results.txt"
  echo "" | tee -a "$OUTDIR/results.txt"
done

# === TLS CERTS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- TLS Certificates ---" | tee -a "$OUTDIR/results.txt"
for domain in "clubdunkin.com" "dnkn.com" "lsmnow.com" "dunkindonuts.co.uk"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "[$domain] cert:" | tee -a "$OUTDIR/results.txt"
  timeout 10 openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "  TLS FAILED" | tee -a "$OUTDIR/results.txt"
done

# === DUNKINNATION.COM INFINITE REDIRECT INVESTIGATION ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"
echo "DUNKINNATION.COM REDIRECT LOOP ANALYSIS" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"

# Don't follow redirects — capture each hop individually
echo "--- Hop-by-hop redirect trace ---" | tee -a "$OUTDIR/results.txt"
URL="http://dunkinnation.com/"
for i in $(seq 1 15); do
  result=$(curl -s --max-time 8 -o /dev/null -w '%{http_code} %{redirect_url}' -D /tmp/hop_headers "$URL" 2>/dev/null)
  status=$(echo "$result" | awk '{print $1}')
  redirect=$(echo "$result" | awk '{print $2}')
  server=$(grep -i '^server:' /tmp/hop_headers 2>/dev/null | head -1 | tr -d '\r')
  location=$(grep -i '^location:' /tmp/hop_headers 2>/dev/null | head -1 | tr -d '\r')
  echo "  Hop $i: $URL → $status" | tee -a "$OUTDIR/results.txt"
  echo "    $location" | tee -a "$OUTDIR/results.txt"
  echo "    $server" | tee -a "$OUTDIR/results.txt"
  if [ "$status" = "301" ] || [ "$status" = "302" ] || [ "$status" = "307" ] || [ "$status" = "308" ]; then
    URL="$redirect"
    [ -z "$URL" ] && break
  else
    break
  fi
done

# Also try HTTPS
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- HTTPS attempt ---" | tee -a "$OUTDIR/results.txt"
curl -sk --max-time 10 -I "https://dunkinnation.com/" 2>/dev/null | head -10 | tee -a "$OUTDIR/results.txt" || echo "  HTTPS FAILED" | tee -a "$OUTDIR/results.txt"

# === DUNKIN SUBDOMAINS FROM CT LOGS (never probed) ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Additional Dunkin Subdomains ---" | tee -a "$OUTDIR/results.txt"
EXTRA_SUBS=(
  "catering.dunkindonuts.com"
  "giftcards.dunkindonuts.com"
  "shop.dunkindonuts.com"
  "staging.shop.dunkindonuts.com"
  "secureshop.dunkindonuts.com"
  "loyalty.dunkindonuts.com"
  "international.dunkindonuts.com"
)
for domain in "${EXTRA_SUBS[@]}"; do
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
  status="DEAD"
  if [ -n "$cname" ] || [ -n "$a" ]; then
    status="LIVE"
    http=$(curl -sk --max-time 8 -o /dev/null -w '%{http_code}' "https://$domain/" 2>/dev/null)
  else
    http="n/a"
  fi
  echo "$status  $domain → CNAME: ${cname:-none} A: ${a:-none} HTTP: $http" | tee -a "$OUTDIR/results.txt"
done

# Capture headers/body for live ones that return 200
for domain in "${EXTRA_SUBS[@]}"; do
  http=$(curl -sk --max-time 8 -o /dev/null -w '%{http_code}' "https://$domain/" 2>/dev/null)
  if [ "$http" = "200" ] || [ "$http" = "301" ] || [ "$http" = "302" ]; then
    safename=$(echo "$domain" | tr '.' '_')
    echo "  Capturing $domain → $safename" | tee -a "$OUTDIR/results.txt"
    curl -sk --max-time 10 -D "$OUTDIR/${safename}.headers" "https://$domain/" > "$OUTDIR/${safename}.body" 2>/dev/null || true
  fi
done

# === WHOIS for new domains ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Whois ---" | tee -a "$OUTDIR/results.txt"
for domain in "clubdunkin.com" "dnkn.com" "lsmnow.com"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "[$domain] whois:" | tee -a "$OUTDIR/results.txt"
  whois "$domain" 2>/dev/null | grep -iE 'Registrant|Registrar|Creation|Expir|Updated|Name Server|Status' | head -15 | tee -a "$OUTDIR/results.txt" || echo "  whois FAILED" | tee -a "$OUTDIR/results.txt"
done

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
echo "Completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
