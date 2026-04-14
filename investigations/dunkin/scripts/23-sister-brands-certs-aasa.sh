#!/bin/bash
# Sister brands: TLS certs, AASA, Android Asset Links, vendor detection
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/sister-brands-certs-2026-04-13:/out:Z \
#   investigator bash /work/scripts/23-sister-brands-certs-aasa.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== SISTER BRANDS: CERTS, AASA, VENDOR DETECTION ===" | tee "$OUTDIR/results.txt"
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

for brand in "${BRANDS[@]}"; do
  short=$(echo "$brand" | cut -d. -f1)

  echo "========================================" | tee -a "$OUTDIR/results.txt"
  echo "BRAND: $brand" | tee -a "$OUTDIR/results.txt"
  echo "========================================" | tee -a "$OUTDIR/results.txt"

  # === TLS CERT ===
  echo "--- TLS Certificate (www.$brand) ---" | tee -a "$OUTDIR/results.txt"
  timeout 10 openssl s_client -connect "www.$brand:443" -servername "www.$brand" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "  TLS FAILED" | tee -a "$OUTDIR/results.txt"

  # Full SANs to file
  timeout 10 openssl s_client -connect "www.$brand:443" -servername "www.$brand" </dev/null 2>/dev/null | openssl x509 -noout -ext subjectAltName 2>/dev/null | tr ',' '\n' | sed 's/^ *//' > "$OUTDIR/${short}-sans.txt" 2>/dev/null || true

  # === APPLE APP SITE ASSOCIATION ===
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "--- Apple App Site Association ---" | tee -a "$OUTDIR/results.txt"
  aasa_status=$(curl -sk --max-time 10 -o "$OUTDIR/${short}-aasa.json" -w '%{http_code}' "https://www.$brand/.well-known/apple-app-site-association" 2>/dev/null)
  echo "  Status: $aasa_status" | tee -a "$OUTDIR/results.txt"
  if [ "$aasa_status" = "200" ]; then
    jq . "$OUTDIR/${short}-aasa.json" 2>/dev/null | head -50 | tee -a "$OUTDIR/results.txt" || cat "$OUTDIR/${short}-aasa.json" | head -50 | tee -a "$OUTDIR/results.txt"
    # Extract app IDs
    echo "  App IDs:" | tee -a "$OUTDIR/results.txt"
    jq -r '.. | .appID? // .appIDs? // empty | if type == "array" then .[] else . end' "$OUTDIR/${short}-aasa.json" 2>/dev/null | sort -u | tee -a "$OUTDIR/results.txt" || true
  fi

  # Try root domain too
  if [ "$aasa_status" != "200" ]; then
    aasa_status2=$(curl -sk --max-time 10 -o "$OUTDIR/${short}-aasa-root.json" -w '%{http_code}' "https://$brand/.well-known/apple-app-site-association" 2>/dev/null)
    if [ "$aasa_status2" = "200" ]; then
      echo "  Found at root domain instead: $aasa_status2" | tee -a "$OUTDIR/results.txt"
      jq . "$OUTDIR/${short}-aasa-root.json" 2>/dev/null | head -50 | tee -a "$OUTDIR/results.txt" || true
    fi
  fi

  # === ANDROID ASSET LINKS ===
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "--- Android Asset Links ---" | tee -a "$OUTDIR/results.txt"
  android_status=$(curl -sk --max-time 10 -o "$OUTDIR/${short}-assetlinks.json" -w '%{http_code}' "https://www.$brand/.well-known/assetlinks.json" 2>/dev/null)
  echo "  Status: $android_status" | tee -a "$OUTDIR/results.txt"
  if [ "$android_status" = "200" ]; then
    jq . "$OUTDIR/${short}-assetlinks.json" 2>/dev/null | head -50 | tee -a "$OUTDIR/results.txt" || cat "$OUTDIR/${short}-assetlinks.json" | head -50 | tee -a "$OUTDIR/results.txt"
    # Extract package names
    echo "  Package names:" | tee -a "$OUTDIR/results.txt"
    jq -r '.[].target.package_name // empty' "$OUTDIR/${short}-assetlinks.json" 2>/dev/null | sort -u | tee -a "$OUTDIR/results.txt" || true
  fi

  # Try root domain
  if [ "$android_status" != "200" ]; then
    android_status2=$(curl -sk --max-time 10 -o "$OUTDIR/${short}-assetlinks-root.json" -w '%{http_code}' "https://$brand/.well-known/assetlinks.json" 2>/dev/null)
    if [ "$android_status2" = "200" ]; then
      echo "  Found at root domain: $android_status2" | tee -a "$OUTDIR/results.txt"
      jq . "$OUTDIR/${short}-assetlinks-root.json" 2>/dev/null | head -50 | tee -a "$OUTDIR/results.txt" || true
    fi
  fi

  # === BRANCH.IO DETECTION ===
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "--- Branch.io Detection ---" | tee -a "$OUTDIR/results.txt"
  for prefix in "$short" "$(echo "$short" | tr '[:upper:]' '[:lower:]')"; do
    for suffix in "smart.link" "app.link" "test-app.link"; do
      bl_a=$(dig +short "$prefix.$suffix" A @8.8.8.8 2>/dev/null | head -1)
      if [ -n "$bl_a" ]; then
        echo "  HIT: $prefix.$suffix → $bl_a" | tee -a "$OUTDIR/results.txt"
      fi
    done
  done
  # Common brand abbreviations
  case "$brand" in
    buffalowildwings.com) extra_prefixes="bww bdubs" ;;
    sonicdrivein.com) extra_prefixes="sonic" ;;
    dunkindonuts.com) extra_prefixes="dunkin" ;;
    baskinrobbins.com) extra_prefixes="baskinrobbins br" ;;
    jimmyjohns.com) extra_prefixes="jimmyjohns jjs" ;;
    arbys.com) extra_prefixes="arbys" ;;
    *) extra_prefixes="" ;;
  esac
  for prefix in $extra_prefixes; do
    for suffix in "smart.link" "app.link" "test-app.link"; do
      bl_a=$(dig +short "$prefix.$suffix" A @8.8.8.8 2>/dev/null | head -1)
      if [ -n "$bl_a" ]; then
        echo "  HIT: $prefix.$suffix → $bl_a" | tee -a "$OUTDIR/results.txt"
      fi
    done
  done

  # === HTTP HEADERS (www) ===
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "--- HTTP Headers (www.$brand) ---" | tee -a "$OUTDIR/results.txt"
  curl -sk --max-time 10 -I "https://www.$brand/" 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "  FAILED" | tee -a "$OUTDIR/results.txt"

  echo "" | tee -a "$OUTDIR/results.txt"
done

echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
echo "Completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
