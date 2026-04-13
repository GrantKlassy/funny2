#!/bin/bash
# Wayback Machine deep dive: historical content for legacy services and vanity domains
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/wayback-deep-dive-2026-04-13:/out:Z \
#   investigator bash /work/scripts/16-wayback-deep-dive.sh
set -euo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== WAYBACK MACHINE DEEP DIVE ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# Helper: query CDX API for a domain
cdx_query() {
  local domain="$1"
  local label="$2"
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> Wayback: $label ($domain)" | tee -a "$OUTDIR/results.txt"
  local result
  result=$(curl -s --max-time 20 "https://web.archive.org/cdx/search/cdx?url=$domain/*&output=json&fl=timestamp,original,statuscode,mimetype&collapse=urlkey&limit=50" 2>/dev/null || echo "TIMEOUT")
  if [ "$result" = "TIMEOUT" ]; then
    echo "  TIMEOUT" | tee -a "$OUTDIR/results.txt"
  elif [ "$result" = "[]" ] || [ -z "$result" ]; then
    echo "  NO RESULTS" | tee -a "$OUTDIR/results.txt"
  elif echo "$result" | jq . >/dev/null 2>&1; then
    local count
    count=$(echo "$result" | jq 'length - 1')
    echo "  $count archived URLs" | tee -a "$OUTDIR/results.txt"
    echo "$result" | jq -r '.[1:][] | "\(.[0]) \(.[2]) \(.[3]) \(.[1])"' 2>/dev/null | head -30 | tee -a "$OUTDIR/results.txt"
  else
    echo "  PARSE ERROR" | tee -a "$OUTDIR/results.txt"
  fi
}

# === LEGACY DUNKINBRANDS.COM SERVICES ===
echo "--- Legacy dunkinbrands.com Services ---" | tee -a "$OUTDIR/results.txt"

cdx_query "franchiseecentral.dunkinbrands.com" "Franchisee Central"
cdx_query "star.dunkinbrands.com" "Star (405 mystery)"
cdx_query "fps.dunkinbrands.com" "FPS (CAAS)"
cdx_query "rbos.dunkinbrands.com" "RBOS"
cdx_query "genesisproduction.dunkinbrands.com" "Genesis Production"
cdx_query "genesissandbox.dunkinbrands.com" "Genesis Sandbox"
cdx_query "thecenter.dunkinbrands.com" "The Center"
cdx_query "citrix.dunkinbrands.com" "Citrix"
cdx_query "smartsolve.dunkinbrands.com" "SmartSolve"
cdx_query "poshc.dunkinbrands.com" "POSHC"
cdx_query "bam.dunkinbrands.com" "BAM"
cdx_query "recognition.dunkinbrands.com" "Recognition"
cdx_query "wsapi.dunkinbrands.com" "WSAPI"
cdx_query "plmsupplier.dunkinbrands.com" "PLM Supplier"

# === VANITY DOMAINS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Vanity Domains ---" | tee -a "$OUTDIR/results.txt"

cdx_query "dunkinrewards.com" "Dunkin Rewards"
cdx_query "dunkinemail.com" "Dunkin Email"
cdx_query "ddperks.com" "DD Perks"
cdx_query "dunkinperks.com" "Dunkin Perks"
cdx_query "dunkinnation.com" "Dunkin Nation"
cdx_query "dunkinrun.com" "Dunkin Run"
cdx_query "ddglobalfranchising.com" "DD Global Franchising"
cdx_query "dunkinfranchising.com" "Dunkin Franchising"
cdx_query "baskinrobbinsfranchising.com" "BR Franchising"

# === QA/DEV ENVIRONMENTS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- QA/Dev Environments ---" | tee -a "$OUTDIR/results.txt"

cdx_query "qa.dunkindonuts.com" "QA"
cdx_query "dev2.dunkindonuts.com" "Dev2"
cdx_query "staging.dunkindonuts.com" "Staging"
cdx_query "uat.dunkindonuts.com" "UAT"
cdx_query "staging3.dunkindonuts.com" "Staging3"

# === INTERESTING SNAPSHOT RETRIEVAL ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Snapshot Retrieval (most interesting hits) ---" | tee -a "$OUTDIR/results.txt"

# franchiseecentral — what was on the 2016 portal?
echo "" | tee -a "$OUTDIR/results.txt"
echo ">> Oldest franchiseecentral snapshot:" | tee -a "$OUTDIR/results.txt"
fc_snap=$(curl -s --max-time 15 "https://web.archive.org/cdx/search/cdx?url=franchiseecentral.dunkinbrands.com&output=json&fl=timestamp&limit=1&from=20100101" 2>/dev/null)
if echo "$fc_snap" | jq -r '.[1][0]' >/dev/null 2>&1; then
  ts=$(echo "$fc_snap" | jq -r '.[1][0]' 2>/dev/null)
  if [ -n "$ts" ] && [ "$ts" != "null" ]; then
    echo "  Timestamp: $ts" | tee -a "$OUTDIR/results.txt"
    curl -s --max-time 15 "https://web.archive.org/web/${ts}/https://franchiseecentral.dunkinbrands.com/" 2>/dev/null | grep -oP '<title>[^<]+</title>' | head -1 | tee -a "$OUTDIR/results.txt" || true
  fi
fi

# rbos — what was it?
echo "" | tee -a "$OUTDIR/results.txt"
echo ">> Oldest RBOS snapshot:" | tee -a "$OUTDIR/results.txt"
rbos_snap=$(curl -s --max-time 15 "https://web.archive.org/cdx/search/cdx?url=rbos.dunkinbrands.com&output=json&fl=timestamp&limit=1&from=20100101" 2>/dev/null)
if echo "$rbos_snap" | jq -r '.[1][0]' >/dev/null 2>&1; then
  ts=$(echo "$rbos_snap" | jq -r '.[1][0]' 2>/dev/null)
  if [ -n "$ts" ] && [ "$ts" != "null" ]; then
    echo "  Timestamp: $ts" | tee -a "$OUTDIR/results.txt"
    curl -s --max-time 15 "https://web.archive.org/web/${ts}/https://rbos.dunkinbrands.com/" 2>/dev/null | grep -oP '<title>[^<]+</title>' | head -1 | tee -a "$OUTDIR/results.txt" || true
  fi
fi

# thecenter — what was it?
echo "" | tee -a "$OUTDIR/results.txt"
echo ">> Oldest The Center snapshot:" | tee -a "$OUTDIR/results.txt"
tc_snap=$(curl -s --max-time 15 "https://web.archive.org/cdx/search/cdx?url=thecenter.dunkinbrands.com&output=json&fl=timestamp&limit=1&from=20100101" 2>/dev/null)
if echo "$tc_snap" | jq -r '.[1][0]' >/dev/null 2>&1; then
  ts=$(echo "$tc_snap" | jq -r '.[1][0]' 2>/dev/null)
  if [ -n "$ts" ] && [ "$ts" != "null" ]; then
    echo "  Timestamp: $ts" | tee -a "$OUTDIR/results.txt"
    curl -s --max-time 15 "https://web.archive.org/web/${ts}/https://thecenter.dunkinbrands.com/" 2>/dev/null | grep -oP '<title>[^<]+</title>' | head -1 | tee -a "$OUTDIR/results.txt" || true
  fi
fi

# ddperks — the OG loyalty program
echo "" | tee -a "$OUTDIR/results.txt"
echo ">> Oldest DD Perks snapshot:" | tee -a "$OUTDIR/results.txt"
dd_snap=$(curl -s --max-time 15 "https://web.archive.org/cdx/search/cdx?url=ddperks.com&output=json&fl=timestamp&limit=1&from=20100101" 2>/dev/null)
if echo "$dd_snap" | jq -r '.[1][0]' >/dev/null 2>&1; then
  ts=$(echo "$dd_snap" | jq -r '.[1][0]' 2>/dev/null)
  if [ -n "$ts" ] && [ "$ts" != "null" ]; then
    echo "  Timestamp: $ts" | tee -a "$OUTDIR/results.txt"
    curl -s --max-time 15 "https://web.archive.org/web/${ts}/https://ddperks.com/" 2>/dev/null | grep -oP '<title>[^<]+</title>' | head -1 | tee -a "$OUTDIR/results.txt" || true
  fi
fi

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
