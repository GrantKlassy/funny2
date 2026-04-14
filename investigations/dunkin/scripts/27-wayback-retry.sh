#!/bin/bash
# Wayback Machine retry: individual queries with timeouts for all failed targets
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/wayback-retry-2026-04-13:/out:Z \
#   investigator bash /work/scripts/27-wayback-retry.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== WAYBACK MACHINE RETRY ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# Helper: query Wayback CDX with timeout and sleep
wayback_query() {
  local domain="$1"
  local label="$2"

  echo "--- $label ($domain) ---" | tee -a "$OUTDIR/results.txt"
  local safename
  safename=$(echo "$domain" | tr '.' '_')

  local http_code
  http_code=$(curl -s --max-time 30 -o "$OUTDIR/wb-${safename}.json" -w '%{http_code}' \
    "https://web.archive.org/cdx/search/cdx?url=${domain}/*&output=json&limit=20&collapse=urlkey&fl=timestamp,original,statuscode,mimetype" 2>/dev/null)

  if [ "$http_code" = "200" ] && [ -s "$OUTDIR/wb-${safename}.json" ]; then
    local lines
    lines=$(wc -l < "$OUTDIR/wb-${safename}.json" 2>/dev/null || echo 0)
    echo "  SUCCESS: $lines entries" | tee -a "$OUTDIR/results.txt"
    # Pretty-print the results
    jq -r '.[] | "\(.[0]) \(.[2]) \(.[3]) \(.[1])"' "$OUTDIR/wb-${safename}.json" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt" || head -20 "$OUTDIR/wb-${safename}.json" | tee -a "$OUTDIR/results.txt"

    # For any 200 status, try to fetch the actual snapshot
    local first_200_ts first_200_url
    first_200_ts=$(jq -r '.[] | select(.[2] == "200") | .[0]' "$OUTDIR/wb-${safename}.json" 2>/dev/null | head -1)
    first_200_url=$(jq -r '.[] | select(.[2] == "200") | .[1]' "$OUTDIR/wb-${safename}.json" 2>/dev/null | head -1)
    if [ -n "$first_200_ts" ] && [ -n "$first_200_url" ]; then
      echo "  Fetching snapshot: $first_200_ts $first_200_url" | tee -a "$OUTDIR/results.txt"
      curl -s --max-time 20 -o "$OUTDIR/wb-${safename}-snapshot.html" \
        "https://web.archive.org/web/${first_200_ts}/${first_200_url}" 2>/dev/null || true
      local snap_size
      snap_size=$(wc -c < "$OUTDIR/wb-${safename}-snapshot.html" 2>/dev/null || echo 0)
      echo "  Snapshot size: ${snap_size} bytes" | tee -a "$OUTDIR/results.txt"
    fi
  else
    echo "  FAILED (HTTP $http_code)" | tee -a "$OUTDIR/results.txt"
  fi
  echo "" | tee -a "$OUTDIR/results.txt"
  sleep 2
}

# === RETRIES FROM WAVE 2 (script 16 failures) ===
echo "=== RETRIES FROM PREVIOUS WAVE ===" | tee -a "$OUTDIR/results.txt"
wayback_query "franchiseecentral.dunkinbrands.com" "Franchisee Central"
wayback_query "star.dunkinbrands.com" "Star Service"
wayback_query "fps.dunkinbrands.com" "FPS (CAAS)"
wayback_query "rbos.dunkinbrands.com" "RBOS (CAAS)"
wayback_query "genesisproduction.dunkinbrands.com" "Genesis Production"
wayback_query "dunkinemail.com" "Dunkin Email"
wayback_query "plmsupplier.dunkinbrands.com" "PLM Supplier"

# === NEW TARGETS ===
echo "=== NEW TARGETS ===" | tee -a "$OUTDIR/results.txt"
wayback_query "auth0-stg.dunkindonuts.com" "Auth0 Staging"
wayback_query "clubdunkin.com" "Club Dunkin"
wayback_query "dnkn.com" "DNKN"
wayback_query "lsmnow.com" "LSM Now"

# === SANDBOX DOMAINS ===
echo "=== SANDBOX DOMAINS ===" | tee -a "$OUTDIR/results.txt"
wayback_query "loyalty-api.sandbox.dunkindonuts.com" "Loyalty API Sandbox"
wayback_query "loyalty-mock-api.sandbox.dunkindonuts.com" "Loyalty Mock API Sandbox"
wayback_query "rewards-api.sandbox.dunkindonuts.com" "Rewards API Sandbox"
wayback_query "oats-api.sandbox.dunkindonuts.com" "OATS API Sandbox"
wayback_query "oats-ws.sandbox.dunkindonuts.com" "OATS WebSocket Sandbox"
wayback_query "swagger.sandbox.dunkindonuts.com" "Swagger Sandbox"
wayback_query "swagger.ddmdev.dunkindonuts.com" "Swagger DDM Dev"

echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
echo "Completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
