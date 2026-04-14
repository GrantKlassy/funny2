#!/bin/bash
# Loyalty program rebrand archaeology: hop-by-hop redirect chains
# dunkinemail.com does 5 redirects through 3 rebrands → 403. Map the entire chain.
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/rebrand-archaeology-2026-04-13:/out:Z \
#   investigator bash /work/scripts/35-rebrand-archaeology.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== LOYALTY PROGRAM REBRAND ARCHAEOLOGY ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# === HOP-BY-HOP REDIRECT CHAINS ===
# The money shot: trace each redirect individually, capture headers and body at each hop
DOMAINS=(
  "dunkinemail.com"
  "ddperks.com"
  "dunkinperks.com"
  "dunkinrewards.com"
  "clubdunkin.com"
)

trace_redirects() {
  local url="$1"
  local label="$2"
  local hop=0
  local max_hops=12

  echo "" | tee -a "$OUTDIR/results.txt"
  echo "[$label] Redirect chain:" | tee -a "$OUTDIR/results.txt"
  echo "  START: $url" | tee -a "$OUTDIR/results.txt"

  while [ $hop -lt $max_hops ]; do
    hop=$((hop + 1))
    local safe_label=$(echo "$label-hop$hop" | tr '/:' '_')

    # Capture response WITHOUT following redirects
    local http_code=$(curl -sk --max-time 15 \
      -D "$OUTDIR/${safe_label}-headers.txt" \
      -o "$OUTDIR/${safe_label}-body.txt" \
      -w '%{http_code}' "$url" 2>/dev/null)

    local body_size=$(wc -c < "$OUTDIR/${safe_label}-body.txt" 2>/dev/null)
    local server=$(grep -i '^server:' "$OUTDIR/${safe_label}-headers.txt" 2>/dev/null | head -1 | tr -d '\r')
    local location=$(grep -i '^location:' "$OUTDIR/${safe_label}-headers.txt" 2>/dev/null | head -1 | sed 's/^[Ll]ocation: *//' | tr -d '\r')
    local set_cookie=$(grep -i '^set-cookie:' "$OUTDIR/${safe_label}-headers.txt" 2>/dev/null | head -1 | tr -d '\r')
    local x_headers=$(grep -i '^x-' "$OUTDIR/${safe_label}-headers.txt" 2>/dev/null | tr -d '\r' | head -5 | tr '\n' ' | ')

    echo "  HOP $hop: $url" | tee -a "$OUTDIR/results.txt"
    echo "    Status: $http_code | Body: ${body_size}B | ${server:-no server}" | tee -a "$OUTDIR/results.txt"
    [ -n "$set_cookie" ] && echo "    $set_cookie" | tee -a "$OUTDIR/results.txt"
    [ -n "$x_headers" ] && echo "    X-headers: $x_headers" | tee -a "$OUTDIR/results.txt"

    # Check for title in body
    local title=$(grep -oi '<title>[^<]*</title>' "$OUTDIR/${safe_label}-body.txt" 2>/dev/null | head -1)
    [ -n "$title" ] && echo "    Title: $title" | tee -a "$OUTDIR/results.txt"

    # If it's a redirect, follow
    if [[ "$http_code" =~ ^3[0-9][0-9]$ ]] && [ -n "$location" ]; then
      echo "    → Location: $location" | tee -a "$OUTDIR/results.txt"
      url="$location"
    else
      echo "    TERMINAL ($http_code)" | tee -a "$OUTDIR/results.txt"
      break
    fi
  done
}

for domain in "${DOMAINS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "========================================" | tee -a "$OUTDIR/results.txt"
  echo "DOMAIN: $domain" | tee -a "$OUTDIR/results.txt"
  echo "========================================" | tee -a "$OUTDIR/results.txt"

  # DNS first
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
  ns=$(dig +short "$domain" NS @8.8.8.8 2>/dev/null | head -2 | tr '\n' ',' | sed 's/,$//')
  echo "  A: ${a:-NXDOMAIN}  CNAME: ${cname:-none}  NS: ${ns:-none}" | tee -a "$OUTDIR/results.txt"

  # HTTPS chain
  trace_redirects "https://$domain/" "https-$domain"

  # HTTP chain (may differ)
  trace_redirects "http://$domain/" "http-$domain"

  # www variants
  trace_redirects "https://www.$domain/" "https-www-$domain"

  sleep 1
done

# === DUNKINEMAIL.COM PATH SWEEP ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- dunkinemail.com Path Sweep ---" | tee -a "$OUTDIR/results.txt"
PATHS=("/unsubscribe" "/preferences" "/track" "/rewards" "/signup" "/manage" "/optout" "/login" "/register")
for path in "${PATHS[@]}"; do
  status=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' "https://dunkinemail.com$path" 2>/dev/null)
  echo "  dunkinemail.com$path → $status" | tee -a "$OUTDIR/results.txt"
done

# === TLS CERTS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- TLS Certificates ---" | tee -a "$OUTDIR/results.txt"
for domain in "${DOMAINS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "[$domain]:" | tee -a "$OUTDIR/results.txt"
  echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | tee -a "$OUTDIR/results.txt"
done

# === WAYBACK CDX ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Wayback Machine CDX ---" | tee -a "$OUTDIR/results.txt"
for domain in "${DOMAINS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "[$domain] Wayback snapshots:" | tee -a "$OUTDIR/results.txt"
  curl -s --max-time 30 "http://web.archive.org/cdx/search/cdx?url=${domain}&matchType=domain&output=json&limit=20&fl=timestamp,original,statuscode,mimetype" -o "$OUTDIR/${domain}-wayback.json" 2>/dev/null
  if [ -f "$OUTDIR/${domain}-wayback.json" ]; then
    cat "$OUTDIR/${domain}-wayback.json" 2>/dev/null | jq -r '.[] | "\(.[0]) \(.[1]) \(.[2]) \(.[3])"' 2>/dev/null | tail -20 | tee -a "$OUTDIR/results.txt"
  fi
  sleep 2
done

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== PROBE COMPLETE ===" | tee -a "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
