#!/bin/bash
# Deep DNS enumeration for all 6 Inspire Brands: NS, MX, TXT, DKIM, CAA, SOA, CDN chains
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/sister-brands-deep-2026-04-13:/out:Z \
#   investigator bash /work/scripts/22-sister-brands-deep-dns.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== SISTER BRANDS DEEP DNS ENUMERATION ===" | tee "$OUTDIR/results.txt"
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

DKIM_SELECTORS=(
  "google" "s1" "s2" "k1" "k2"
  "selector1" "selector2"
  "em" "braze" "sailthru" "sendgrid" "mandrill" "sparkpost"
  "default" "mail" "cm" "sf" "mcdkim"
)

for brand in "${BRANDS[@]}"; do
  echo "========================================" | tee -a "$OUTDIR/results.txt"
  echo "BRAND: $brand" | tee -a "$OUTDIR/results.txt"
  echo "========================================" | tee -a "$OUTDIR/results.txt"

  # NS
  echo "--- NS ---" | tee -a "$OUTDIR/results.txt"
  dig +short "$brand" NS @8.8.8.8 2>/dev/null | sort | tee -a "$OUTDIR/results.txt"

  # SOA
  echo "--- SOA ---" | tee -a "$OUTDIR/results.txt"
  dig +short "$brand" SOA @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

  # MX
  echo "--- MX ---" | tee -a "$OUTDIR/results.txt"
  dig +short "$brand" MX @8.8.8.8 2>/dev/null | sort | tee -a "$OUTDIR/results.txt"

  # TXT (SPF, verification records)
  echo "--- TXT ---" | tee -a "$OUTDIR/results.txt"
  dig +short "$brand" TXT @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

  # DMARC
  echo "--- DMARC ---" | tee -a "$OUTDIR/results.txt"
  dig +short "_dmarc.$brand" TXT @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

  # CAA
  echo "--- CAA ---" | tee -a "$OUTDIR/results.txt"
  dig +short "$brand" CAA @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "  none" | tee -a "$OUTDIR/results.txt"

  # DKIM selector sweep
  echo "--- DKIM Selectors ---" | tee -a "$OUTDIR/results.txt"
  for sel in "${DKIM_SELECTORS[@]}"; do
    dkim=$(dig +short "${sel}._domainkey.$brand" TXT @8.8.8.8 2>/dev/null | head -1)
    if [ -n "$dkim" ]; then
      echo "  HIT: ${sel}._domainkey.$brand" | tee -a "$OUTDIR/results.txt"
      echo "    $dkim" | tee -a "$OUTDIR/results.txt"
    fi
  done

  # www CNAME chain (CDN identification)
  echo "--- www CNAME chain ---" | tee -a "$OUTDIR/results.txt"
  current="www.$brand"
  for i in $(seq 1 10); do
    cname=$(dig +short "$current" CNAME @8.8.8.8 2>/dev/null | head -1)
    if [ -n "$cname" ]; then
      echo "  $current → $cname" | tee -a "$OUTDIR/results.txt"
      current="$cname"
    else
      a=$(dig +short "$current" A @8.8.8.8 2>/dev/null | head -1)
      echo "  $current → A: ${a:-none}" | tee -a "$OUTDIR/results.txt"
      break
    fi
  done

  # order.* CNAME chain (ordering vendor)
  echo "--- order CNAME chain ---" | tee -a "$OUTDIR/results.txt"
  current="order.$brand"
  for i in $(seq 1 10); do
    cname=$(dig +short "$current" CNAME @8.8.8.8 2>/dev/null | head -1)
    if [ -n "$cname" ]; then
      echo "  $current → $cname" | tee -a "$OUTDIR/results.txt"
      current="$cname"
    else
      a=$(dig +short "$current" A @8.8.8.8 2>/dev/null | head -1)
      if [ -n "$a" ]; then
        echo "  $current → A: $a" | tee -a "$OUTDIR/results.txt"
      else
        echo "  $current → NXDOMAIN" | tee -a "$OUTDIR/results.txt"
      fi
      break
    fi
  done

  # Root A records
  echo "--- Root A Records ---" | tee -a "$OUTDIR/results.txt"
  dig +short "$brand" A @8.8.8.8 2>/dev/null | sort | tee -a "$OUTDIR/results.txt"

  echo "" | tee -a "$OUTDIR/results.txt"
done

echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
echo "Completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
