#!/bin/bash
# Terry Ursino CT log investigation: email leaked in certificate CN
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/terry-ursino-2026-04-13:/out:Z \
#   investigator bash /work/scripts/28-terry-ursino-certs.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== TERRY URSINO CERTIFICATE TRANSPARENCY INVESTIGATION ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# === EXACT EMAIL QUERY ===
echo "--- crt.sh: terry.ursino@dunkinbrands.com (exact) ---" | tee -a "$OUTDIR/results.txt"
http_code=$(curl -s --max-time 45 -o "$OUTDIR/terry-exact.json" -w '%{http_code}' \
  "https://crt.sh/?q=terry.ursino%40dunkinbrands.com&output=json" 2>/dev/null)
echo "  HTTP: $http_code" | tee -a "$OUTDIR/results.txt"
if [ "$http_code" = "200" ] && [ -s "$OUTDIR/terry-exact.json" ]; then
  count=$(jq length "$OUTDIR/terry-exact.json" 2>/dev/null || echo 0)
  echo "  Entries: $count" | tee -a "$OUTDIR/results.txt"
  echo "" | tee -a "$OUTDIR/results.txt"
  # Extract key fields
  jq -r '.[] | "  ID: \(.id) | CN: \(.common_name) | Issuer: \(.issuer_name) | Not Before: \(.not_before) | Not After: \(.not_after)"' "$OUTDIR/terry-exact.json" 2>/dev/null | tee -a "$OUTDIR/results.txt"
  echo "" | tee -a "$OUTDIR/results.txt"
  # Full SANs for each cert
  echo "  SANs per cert:" | tee -a "$OUTDIR/results.txt"
  jq -r '.[] | "  Cert \(.id): \(.name_value)"' "$OUTDIR/terry-exact.json" 2>/dev/null | tee -a "$OUTDIR/results.txt"
else
  echo "  FAILED" | tee -a "$OUTDIR/results.txt"
fi

sleep 3

# === BROADER QUERY ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- crt.sh: terry.ursino (broader) ---" | tee -a "$OUTDIR/results.txt"
http_code=$(curl -s --max-time 45 -o "$OUTDIR/terry-broad.json" -w '%{http_code}' \
  "https://crt.sh/?q=terry.ursino&output=json" 2>/dev/null)
echo "  HTTP: $http_code" | tee -a "$OUTDIR/results.txt"
if [ "$http_code" = "200" ] && [ -s "$OUTDIR/terry-broad.json" ]; then
  count=$(jq length "$OUTDIR/terry-broad.json" 2>/dev/null || echo 0)
  echo "  Entries: $count" | tee -a "$OUTDIR/results.txt"
  jq -r '.[] | "  ID: \(.id) | CN: \(.common_name) | Issuer: \(.issuer_name) | Not Before: \(.not_before) | Not After: \(.not_after)"' "$OUTDIR/terry-broad.json" 2>/dev/null | tee -a "$OUTDIR/results.txt"
else
  echo "  FAILED" | tee -a "$OUTDIR/results.txt"
fi

sleep 3

# === CHECK FOR OTHER PERSONAL EMAILS IN DUNKINBRANDS CERTS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- crt.sh: %@dunkinbrands.com (all employee emails in certs) ---" | tee -a "$OUTDIR/results.txt"
http_code=$(curl -s --max-time 60 -o "$OUTDIR/dunkinbrands-emails.json" -w '%{http_code}' \
  "https://crt.sh/?q=%25%40dunkinbrands.com&output=json" 2>/dev/null)
echo "  HTTP: $http_code" | tee -a "$OUTDIR/results.txt"
if [ "$http_code" = "200" ] && [ -s "$OUTDIR/dunkinbrands-emails.json" ]; then
  count=$(jq length "$OUTDIR/dunkinbrands-emails.json" 2>/dev/null || echo 0)
  echo "  Entries: $count" | tee -a "$OUTDIR/results.txt"
  # Extract unique email-like CNs
  echo "  Unique email CNs:" | tee -a "$OUTDIR/results.txt"
  jq -r '.[].common_name // empty' "$OUTDIR/dunkinbrands-emails.json" 2>/dev/null | grep '@' | sort -u | tee -a "$OUTDIR/results.txt"
  echo "  Unique email name_values:" | tee -a "$OUTDIR/results.txt"
  jq -r '.[].name_value // empty' "$OUTDIR/dunkinbrands-emails.json" 2>/dev/null | grep '@' | sort -u | tee -a "$OUTDIR/results.txt"
else
  echo "  FAILED" | tee -a "$OUTDIR/results.txt"
fi

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
echo "Completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
