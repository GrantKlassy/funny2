#!/bin/bash
# Marketing Intelligence, secureshop/Delivery Agent, and UK domain ghost hunt
# Three unrelated quick-hit targets bundled for efficiency
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/marketing-intel-2026-04-13:/out:Z \
#   investigator bash /work/scripts/38-marketing-intelligence.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== MARKETING INTELLIGENCE / SECURESHOP / UK DOMAIN PROBE ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# ===================================================================
# TARGET 1: mi.dunkindonuts.com — "Marketing Intelligence"
# Returns HTTP 200 on CloudFront. What is it?
# ===================================================================
echo "========================================" | tee -a "$OUTDIR/results.txt"
echo "TARGET 1: mi.dunkindonuts.com" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"

# DNS
echo "--- DNS ---" | tee -a "$OUTDIR/results.txt"
dig +short mi.dunkindonuts.com A @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
dig +short mi.dunkindonuts.com CNAME @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

# TLS cert
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- TLS Certificate ---" | tee -a "$OUTDIR/results.txt"
echo | openssl s_client -servername mi.dunkindonuts.com -connect mi.dunkindonuts.com:443 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | tee -a "$OUTDIR/results.txt"

# HTTP probe: full headers + body
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- HTTP Probe ---" | tee -a "$OUTDIR/results.txt"
curl -sk --max-time 20 -D "$OUTDIR/mi-headers.txt" -o "$OUTDIR/mi-body.html" "https://mi.dunkindonuts.com/" 2>/dev/null
status=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' "https://mi.dunkindonuts.com/" 2>/dev/null)
echo "Status: $status" | tee -a "$OUTDIR/results.txt"
cat "$OUTDIR/mi-headers.txt" 2>/dev/null | tee -a "$OUTDIR/results.txt"
size=$(wc -c < "$OUTDIR/mi-body.html" 2>/dev/null)
echo "Body: ${size:-0} bytes" | tee -a "$OUTDIR/results.txt"
head -30 "$OUTDIR/mi-body.html" 2>/dev/null | tee -a "$OUTDIR/results.txt"

# Title and meta
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Body Analysis ---" | tee -a "$OUTDIR/results.txt"
grep -oi '<title>[^<]*</title>' "$OUTDIR/mi-body.html" 2>/dev/null | tee -a "$OUTDIR/results.txt"
grep -oi '<meta[^>]*>' "$OUTDIR/mi-body.html" 2>/dev/null | head -10 | tee -a "$OUTDIR/results.txt"

# Path sweep
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Path Sweep ---" | tee -a "$OUTDIR/results.txt"
MI_PATHS=("/" "/api" "/dashboard" "/data" "/reports" "/login" "/v1" "/graphql" "/health" "/status" "/admin" "/analytics" "/pixel" "/track" "/collect" "/1x1.gif" "/mi" "/beacon")
for path in "${MI_PATHS[@]}"; do
  code=$(curl -sk --max-time 8 -o /dev/null -w '%{http_code}' "https://mi.dunkindonuts.com$path" 2>/dev/null)
  echo "  $path → $code" | tee -a "$OUTDIR/results.txt"
done

# Wayback
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Wayback ---" | tee -a "$OUTDIR/results.txt"
curl -s --max-time 30 "http://web.archive.org/cdx/search/cdx?url=mi.dunkindonuts.com&matchType=host&output=json&limit=20&fl=timestamp,original,statuscode,mimetype" -o "$OUTDIR/mi-wayback.json" 2>/dev/null
jq -r '.[] | "\(.[0]) \(.[1]) \(.[2]) \(.[3])"' "$OUTDIR/mi-wayback.json" 2>/dev/null | tee -a "$OUTDIR/results.txt"
sleep 2

# ===================================================================
# TARGET 2: secureshop.dunkindonuts.com → deliveryagent.com
# DNS pointing to a vendor that may not exist anymore
# ===================================================================
echo "" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"
echo "TARGET 2: secureshop.dunkindonuts.com" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"

# DNS CNAME chain
echo "--- DNS ---" | tee -a "$OUTDIR/results.txt"
dig +short secureshop.dunkindonuts.com CNAME @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
dig +short secureshop.dunkindonuts.com A @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
dig +trace secureshop.dunkindonuts.com CNAME @8.8.8.8 2>/dev/null | tail -10 | tee -a "$OUTDIR/results.txt"

# Probe deliveryagent.com itself
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- deliveryagent.com ---" | tee -a "$OUTDIR/results.txt"
dig +short deliveryagent.com A @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
dig +short deliveryagent.com NS @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
dig +short deliveryagent.com MX @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
status_da=$(curl -sk --max-time 15 -o /dev/null -w '%{http_code}' "https://deliveryagent.com/" 2>/dev/null)
echo "deliveryagent.com HTTPS: $status_da" | tee -a "$OUTDIR/results.txt"
status_da_http=$(curl -s --max-time 15 -o /dev/null -w '%{http_code}' "http://deliveryagent.com/" 2>/dev/null)
echo "deliveryagent.com HTTP: $status_da_http" | tee -a "$OUTDIR/results.txt"

# Whois
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- deliveryagent.com whois ---" | tee -a "$OUTDIR/results.txt"
whois deliveryagent.com 2>/dev/null | grep -i -E 'registr|creat|expir|updated|name server|status|organization|state' | head -15 | tee -a "$OUTDIR/results.txt"

# Wayback for both
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Wayback: secureshop ---" | tee -a "$OUTDIR/results.txt"
curl -s --max-time 30 "http://web.archive.org/cdx/search/cdx?url=secureshop.dunkindonuts.com&matchType=host&output=json&limit=20&fl=timestamp,original,statuscode,mimetype" -o "$OUTDIR/secureshop-wayback.json" 2>/dev/null
jq -r '.[] | "\(.[0]) \(.[1]) \(.[2]) \(.[3])"' "$OUTDIR/secureshop-wayback.json" 2>/dev/null | tee -a "$OUTDIR/results.txt"
sleep 2

echo "--- Wayback: deliveryagent.com ---" | tee -a "$OUTDIR/results.txt"
curl -s --max-time 30 "http://web.archive.org/cdx/search/cdx?url=deliveryagent.com&matchType=domain&output=json&limit=20&fl=timestamp,original,statuscode,mimetype" -o "$OUTDIR/deliveryagent-wayback.json" 2>/dev/null
jq -r '.[] | "\(.[0]) \(.[1]) \(.[2]) \(.[3])"' "$OUTDIR/deliveryagent-wayback.json" 2>/dev/null | tee -a "$OUTDIR/results.txt"
sleep 2

# ===================================================================
# TARGET 3: dunkindonuts.co.uk — Ghost of British Dunkin'
# Found in vanity cert SANs. Dunkin' exited UK market.
# ===================================================================
echo "" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"
echo "TARGET 3: dunkindonuts.co.uk" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"

# DNS full
echo "--- DNS ---" | tee -a "$OUTDIR/results.txt"
for rt in A CNAME NS MX TXT SOA; do
  echo "  $rt:" | tee -a "$OUTDIR/results.txt"
  dig +short dunkindonuts.co.uk $rt @8.8.8.8 2>/dev/null | head -5 | sed 's/^/    /' | tee -a "$OUTDIR/results.txt"
done

# www variant
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- www.dunkindonuts.co.uk DNS ---" | tee -a "$OUTDIR/results.txt"
dig +short www.dunkindonuts.co.uk A @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
dig +short www.dunkindonuts.co.uk CNAME @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

# HTTP probe
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- HTTP Probe ---" | tee -a "$OUTDIR/results.txt"
for variant in "dunkindonuts.co.uk" "www.dunkindonuts.co.uk"; do
  for proto in "https" "http"; do
    status=$(curl -sk --max-time 15 -o /dev/null -w '%{http_code}' "$proto://$variant/" 2>/dev/null)
    location=""
    if [[ "$status" =~ ^3 ]]; then
      location=$(curl -sk --max-time 10 -D - -o /dev/null "$proto://$variant/" 2>/dev/null | grep -i '^location:' | head -1 | tr -d '\r')
    fi
    echo "  $proto://$variant/ → $status ${location:+($location)}" | tee -a "$OUTDIR/results.txt"
  done
done

# TLS cert
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- TLS Certificate ---" | tee -a "$OUTDIR/results.txt"
echo | openssl s_client -servername dunkindonuts.co.uk -connect dunkindonuts.co.uk:443 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | tee -a "$OUTDIR/results.txt"

# Whois
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Whois ---" | tee -a "$OUTDIR/results.txt"
whois dunkindonuts.co.uk 2>/dev/null | head -40 | tee -a "$OUTDIR/results.txt"

# Subdomains
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- UK Subdomains ---" | tee -a "$OUTDIR/results.txt"
UK_SUBS=("app" "order" "careers" "login" "api" "staging" "dev" "m" "mobile" "shop" "store")
for sub in "${UK_SUBS[@]}"; do
  a=$(dig +short "$sub.dunkindonuts.co.uk" A @8.8.8.8 2>/dev/null | head -1)
  echo "  $sub.dunkindonuts.co.uk → ${a:-NXDOMAIN}" | tee -a "$OUTDIR/results.txt"
done

# Wayback
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Wayback ---" | tee -a "$OUTDIR/results.txt"
curl -s --max-time 30 "http://web.archive.org/cdx/search/cdx?url=dunkindonuts.co.uk&matchType=domain&output=json&limit=30&fl=timestamp,original,statuscode,mimetype" -o "$OUTDIR/uk-wayback.json" 2>/dev/null
jq -r '.[] | "\(.[0]) \(.[1]) \(.[2]) \(.[3])"' "$OUTDIR/uk-wayback.json" 2>/dev/null | tee -a "$OUTDIR/results.txt"

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== PROBE COMPLETE ===" | tee -a "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
