#!/bin/bash
# Terry Ursino cert retry + Theorem LP investigation + open naming questions
# crt.sh was 502 on all prior attempts. Also probe Theorem LP (wrong cert on wsapi).
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/terry-theorem-2026-04-13:/out:Z \
#   investigator bash /work/scripts/41-terry-theorem-retry.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== TERRY URSINO + THEOREM LP INVESTIGATION ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# === TERRY URSINO CERT SEARCH (retry) ===
echo "--- crt.sh: Terry Ursino ---" | tee -a "$OUTDIR/results.txt"

# Try exact email
echo "[terry.ursino@dunkinbrands.com]:" | tee -a "$OUTDIR/results.txt"
curl -s --max-time 60 "https://crt.sh/?q=terry.ursino%40dunkinbrands.com&output=json" -o "$OUTDIR/terry-exact.json" 2>/dev/null
status=$?
if [ $status -eq 0 ] && [ -f "$OUTDIR/terry-exact.json" ]; then
  size=$(wc -c < "$OUTDIR/terry-exact.json")
  echo "  Response: $size bytes (exit: $status)" | tee -a "$OUTDIR/results.txt"
  count=$(jq length "$OUTDIR/terry-exact.json" 2>/dev/null)
  echo "  Certs: ${count:-parse error}" | tee -a "$OUTDIR/results.txt"
  jq -r '.[] | "\(.id) \(.common_name) \(.issuer_name) \(.not_before) \(.not_after)"' "$OUTDIR/terry-exact.json" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"
else
  echo "  FAILED (exit: $status)" | tee -a "$OUTDIR/results.txt"
fi
sleep 5

# Try broader search: all email certs for dunkinbrands.com
echo "" | tee -a "$OUTDIR/results.txt"
echo "[%@dunkinbrands.com]:" | tee -a "$OUTDIR/results.txt"
curl -s --max-time 60 "https://crt.sh/?q=%25%40dunkinbrands.com&output=json" -o "$OUTDIR/dunkinbrands-emails.json" 2>/dev/null
status=$?
if [ $status -eq 0 ] && [ -f "$OUTDIR/dunkinbrands-emails.json" ]; then
  size=$(wc -c < "$OUTDIR/dunkinbrands-emails.json")
  echo "  Response: $size bytes (exit: $status)" | tee -a "$OUTDIR/results.txt"
  count=$(jq length "$OUTDIR/dunkinbrands-emails.json" 2>/dev/null)
  echo "  Certs: ${count:-parse error}" | tee -a "$OUTDIR/results.txt"
  jq -r '.[] | "\(.id) \(.common_name)"' "$OUTDIR/dunkinbrands-emails.json" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"
else
  echo "  FAILED (exit: $status)" | tee -a "$OUTDIR/results.txt"
fi
sleep 5

# Try searching for terry.ursino as a name value (not email)
echo "" | tee -a "$OUTDIR/results.txt"
echo "[terry.ursino (name value)]:" | tee -a "$OUTDIR/results.txt"
curl -s --max-time 60 "https://crt.sh/?q=terry.ursino&output=json" -o "$OUTDIR/terry-name.json" 2>/dev/null
if [ -f "$OUTDIR/terry-name.json" ]; then
  count=$(jq length "$OUTDIR/terry-name.json" 2>/dev/null)
  echo "  Certs: ${count:-parse error}" | tee -a "$OUTDIR/results.txt"
  jq -r '.[] | "\(.id) \(.common_name) \(.name_value)"' "$OUTDIR/terry-name.json" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"
fi
sleep 5

# === THEOREM LP INVESTIGATION ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"
echo "THEOREM LP INVESTIGATION" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"

THEOREM_DOMAINS=("theoremlp.com" "www.theoremlp.com" "api-test.theoremlp.com" "api.theoremlp.com" "app.theoremlp.com" "staging.theoremlp.com")

echo "--- DNS ---" | tee -a "$OUTDIR/results.txt"
for domain in "${THEOREM_DOMAINS[@]}"; do
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
  echo "$domain  A: ${a:-NXDOMAIN}  CNAME: ${cname:-none}" | tee -a "$OUTDIR/results.txt"
done

# HTTP probe
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- HTTP Probe ---" | tee -a "$OUTDIR/results.txt"
for domain in "${THEOREM_DOMAINS[@]}"; do
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -1)
  cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
  if [ -z "$a" ] && [ -z "$cname" ]; then continue; fi
  safe=$(echo "$domain" | tr '.' '-')
  status=$(curl -sk --max-time 15 -D "$OUTDIR/theorem-${safe}-headers.txt" -o "$OUTDIR/theorem-${safe}-body.html" -w '%{http_code}' "https://$domain/" 2>/dev/null)
  echo "[$domain] → $status" | tee -a "$OUTDIR/results.txt"
  if [ "$status" != "000" ]; then
    head -10 "$OUTDIR/theorem-${safe}-headers.txt" 2>/dev/null | tee -a "$OUTDIR/results.txt"
    size=$(wc -c < "$OUTDIR/theorem-${safe}-body.html" 2>/dev/null)
    echo "  Body: ${size:-0} bytes" | tee -a "$OUTDIR/results.txt"
    title=$(grep -oi '<title>[^<]*</title>' "$OUTDIR/theorem-${safe}-body.html" 2>/dev/null | head -1)
    [ -n "$title" ] && echo "  $title" | tee -a "$OUTDIR/results.txt"
  fi
done

# TLS cert for api-test.theoremlp.com (the one found on wsapi.dunkinbrands.com)
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- TLS Cert: api-test.theoremlp.com ---" | tee -a "$OUTDIR/results.txt"
echo | openssl s_client -servername api-test.theoremlp.com -connect api-test.theoremlp.com:443 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | tee -a "$OUTDIR/results.txt"

# Whois
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Theorem whois ---" | tee -a "$OUTDIR/results.txt"
whois theoremlp.com 2>/dev/null | grep -i -E 'registr|creat|expir|updated|name server|status|organization|state|tech|admin' | head -20 | tee -a "$OUTDIR/results.txt"

# CT logs for Theorem
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- crt.sh: Theorem LP ---" | tee -a "$OUTDIR/results.txt"
curl -s --max-time 45 "https://crt.sh/?q=%25.theoremlp.com&output=json" -o "$OUTDIR/theorem-certs.json" 2>/dev/null
if [ -f "$OUTDIR/theorem-certs.json" ]; then
  count=$(jq length "$OUTDIR/theorem-certs.json" 2>/dev/null)
  echo "  Certs: ${count:-0}" | tee -a "$OUTDIR/results.txt"
  jq -r '.[].name_value' "$OUTDIR/theorem-certs.json" 2>/dev/null | sort -u | tee -a "$OUTDIR/results.txt"
fi
sleep 3

# Wayback for Theorem + wsapi
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Wayback: theoremlp.com ---" | tee -a "$OUTDIR/results.txt"
curl -s --max-time 30 "http://web.archive.org/cdx/search/cdx?url=theoremlp.com&matchType=domain&output=json&limit=20&fl=timestamp,original,statuscode,mimetype" -o "$OUTDIR/theorem-wayback.json" 2>/dev/null
jq -r '.[] | "\(.[0]) \(.[1]) \(.[2]) \(.[3])"' "$OUTDIR/theorem-wayback.json" 2>/dev/null | tee -a "$OUTDIR/results.txt"
sleep 2

echo "--- Wayback: wsapi.dunkinbrands.com ---" | tee -a "$OUTDIR/results.txt"
curl -s --max-time 30 "http://web.archive.org/cdx/search/cdx?url=wsapi.dunkinbrands.com&matchType=host&output=json&limit=20&fl=timestamp,original,statuscode,mimetype" -o "$OUTDIR/wsapi-wayback.json" 2>/dev/null
jq -r '.[] | "\(.[0]) \(.[1]) \(.[2]) \(.[3])"' "$OUTDIR/wsapi-wayback.json" 2>/dev/null | tee -a "$OUTDIR/results.txt"
sleep 2

# === OPEN NAMING QUESTIONS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"
echo "OPEN NAMING QUESTIONS (Wayback)" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"

echo "--- Wayback: bam.dunkinbrands.com ---" | tee -a "$OUTDIR/results.txt"
curl -s --max-time 30 "http://web.archive.org/cdx/search/cdx?url=bam.dunkinbrands.com&matchType=host&output=json&limit=20&fl=timestamp,original,statuscode,mimetype" -o "$OUTDIR/bam-wayback.json" 2>/dev/null
jq -r '.[] | "\(.[0]) \(.[1]) \(.[2]) \(.[3])"' "$OUTDIR/bam-wayback.json" 2>/dev/null | tee -a "$OUTDIR/results.txt"
sleep 2

echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Wayback: flq-prod-idp.dunkinbrands.com ---" | tee -a "$OUTDIR/results.txt"
curl -s --max-time 30 "http://web.archive.org/cdx/search/cdx?url=flq-prod-idp.dunkinbrands.com&matchType=host&output=json&limit=20&fl=timestamp,original,statuscode,mimetype" -o "$OUTDIR/flq-wayback.json" 2>/dev/null
jq -r '.[] | "\(.[0]) \(.[1]) \(.[2]) \(.[3])"' "$OUTDIR/flq-wayback.json" 2>/dev/null | tee -a "$OUTDIR/results.txt"

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== PROBE COMPLETE ===" | tee -a "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
