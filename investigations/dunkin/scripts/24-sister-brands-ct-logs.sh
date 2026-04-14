#!/bin/bash
# CT log queries for all Inspire Brands + retry dunkinbrands.com
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/sister-brands-ct-2026-04-13:/out:Z \
#   investigator bash /work/scripts/24-sister-brands-ct-logs.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== SISTER BRANDS CT LOG QUERIES ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# Query crt.sh with retry logic and individual timeouts
query_crtsh() {
  local domain="$1"
  local outfile="$2"
  local label="$3"

  echo "--- $label: %.${domain} ---" | tee -a "$OUTDIR/results.txt"
  echo "  Querying crt.sh..." | tee -a "$OUTDIR/results.txt"

  # Try JSON endpoint first
  local http_code
  http_code=$(curl -s --max-time 45 -o "$outfile.json" -w '%{http_code}' \
    "https://crt.sh/?q=%25.${domain}&output=json" 2>/dev/null)

  if [ "$http_code" = "200" ] && [ -s "$outfile.json" ]; then
    local count
    count=$(jq length "$outfile.json" 2>/dev/null || echo 0)
    echo "  SUCCESS: $count entries" | tee -a "$OUTDIR/results.txt"

    # Extract unique subdomains
    jq -r '.[].common_name // empty' "$outfile.json" 2>/dev/null | sort -u > "$outfile-cn.txt" || true
    jq -r '.[].name_value // empty' "$outfile.json" 2>/dev/null | tr '\n' '\n' | sort -u > "$outfile-names.txt" || true

    # Merge and dedupe
    cat "$outfile-cn.txt" "$outfile-names.txt" 2>/dev/null | sort -u | grep -i "$domain" > "$outfile-subdomains.txt" || true
    local subdomain_count
    subdomain_count=$(wc -l < "$outfile-subdomains.txt" 2>/dev/null || echo 0)
    echo "  Unique subdomains: $subdomain_count" | tee -a "$OUTDIR/results.txt"

    # Show first 30 subdomains
    head -30 "$outfile-subdomains.txt" 2>/dev/null | tee -a "$OUTDIR/results.txt"
    if [ "$subdomain_count" -gt 30 ]; then
      echo "  ... and $((subdomain_count - 30)) more" | tee -a "$OUTDIR/results.txt"
    fi

    # Extract unique issuers
    echo "  Cert Issuers:" | tee -a "$OUTDIR/results.txt"
    jq -r '.[].issuer_name // empty' "$outfile.json" 2>/dev/null | sort | uniq -c | sort -rn | head -10 | tee -a "$OUTDIR/results.txt"

    # Categorize subdomains
    echo "  Environment breakdown:" | tee -a "$OUTDIR/results.txt"
    for env in dev qa staging stg uat preprod sandbox test; do
      env_count=$(grep -ci "$env" "$outfile-subdomains.txt" 2>/dev/null || echo 0)
      if [ "$env_count" -gt 0 ]; then
        echo "    $env: $env_count" | tee -a "$OUTDIR/results.txt"
      fi
    done
  else
    echo "  FAILED (HTTP $http_code) — retrying in 5s..." | tee -a "$OUTDIR/results.txt"
    sleep 5
    http_code=$(curl -s --max-time 60 -o "$outfile.json" -w '%{http_code}' \
      "https://crt.sh/?q=%25.${domain}&output=json" 2>/dev/null)
    if [ "$http_code" = "200" ] && [ -s "$outfile.json" ]; then
      local count
      count=$(jq length "$outfile.json" 2>/dev/null || echo 0)
      echo "  RETRY SUCCESS: $count entries" | tee -a "$OUTDIR/results.txt"
      jq -r '.[].name_value // empty' "$outfile.json" 2>/dev/null | sort -u | grep -i "$domain" > "$outfile-subdomains.txt" || true
      wc -l < "$outfile-subdomains.txt" 2>/dev/null | xargs -I{} echo "  Unique subdomains: {}" | tee -a "$OUTDIR/results.txt"
      head -30 "$outfile-subdomains.txt" 2>/dev/null | tee -a "$OUTDIR/results.txt"
    else
      echo "  RETRY FAILED (HTTP $http_code)" | tee -a "$OUTDIR/results.txt"
    fi
  fi
  echo "" | tee -a "$OUTDIR/results.txt"
}

# Query each brand with sleep between to avoid rate limiting
query_crtsh "arbys.com" "$OUTDIR/arbys" "Arby's"
sleep 3

query_crtsh "buffalowildwings.com" "$OUTDIR/bww" "Buffalo Wild Wings"
sleep 3

query_crtsh "sonicdrivein.com" "$OUTDIR/sonic" "Sonic Drive-In"
sleep 3

query_crtsh "jimmyjohns.com" "$OUTDIR/jimmyjohns" "Jimmy John's"
sleep 3

query_crtsh "baskinrobbins.com" "$OUTDIR/baskinrobbins" "Baskin-Robbins"
sleep 3

query_crtsh "inspirebrands.com" "$OUTDIR/inspirebrands" "Inspire Brands (parent)"
sleep 3

# RETRY: dunkinbrands.com (timed out in wave 2)
query_crtsh "dunkinbrands.com" "$OUTDIR/dunkinbrands" "Dunkin' Brands (RETRY)"

echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
echo "Completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
