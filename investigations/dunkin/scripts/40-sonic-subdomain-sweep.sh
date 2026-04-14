#!/bin/bash
# Sonic Drive-In 281 CT subdomain deep sweep + Arby's 110
# The brand that put a Slack message in DNS has 281 subdomains to explore
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/sonic-sweep-2026-04-13:/out:Z \
#   -v ./investigations/dunkin/artifacts/sister-brands-ct-2026-04-13:/in:ro \
#   investigator bash /work/scripts/40-sonic-subdomain-sweep.sh
set -uo pipefail

OUTDIR="/out"
INDIR="/in"
mkdir -p "$OUTDIR"

echo "=== SONIC & ARBY'S SUBDOMAIN DEEP SWEEP ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# === SONIC: DNS resolution sweep ===
echo "--- SONIC DNS SWEEP ---" | tee -a "$OUTDIR/results.txt"

# Read subdomain list from probe 24 artifacts
if [ -f "$INDIR/sonic-subdomains.txt" ]; then
  echo "Reading from probe 24 artifacts..." | tee -a "$OUTDIR/results.txt"
  SONIC_FILE="$INDIR/sonic-subdomains.txt"
else
  echo "Querying crt.sh for Sonic subdomains..." | tee -a "$OUTDIR/results.txt"
  curl -s --max-time 60 "https://crt.sh/?q=%25.sonicdrivein.com&output=json" -o "$OUTDIR/sonic-certs.json" 2>/dev/null
  jq -r '.[].name_value' "$OUTDIR/sonic-certs.json" 2>/dev/null | sort -u | grep -v '\*' > "$OUTDIR/sonic-subdomains-fresh.txt" 2>/dev/null
  SONIC_FILE="$OUTDIR/sonic-subdomains-fresh.txt"
  sleep 5
fi

SONIC_LIVE=()
SONIC_DEAD=0
while IFS= read -r sub; do
  # Skip wildcards
  [[ "$sub" == \** ]] && continue
  # Ensure it ends with sonicdrivein.com
  [[ "$sub" != *sonicdrivein.com ]] && continue

  a=$(dig +short "$sub" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  if [ -n "$a" ]; then
    cname=$(dig +short "$sub" CNAME @8.8.8.8 2>/dev/null | head -1)
    echo "LIVE: $sub  A: $a  CNAME: ${cname:-none}" | tee -a "$OUTDIR/results.txt"
    SONIC_LIVE+=("$sub")
  else
    SONIC_DEAD=$((SONIC_DEAD + 1))
  fi
done < "$SONIC_FILE"

echo "" | tee -a "$OUTDIR/results.txt"
echo "Sonic: ${#SONIC_LIVE[@]} live, $SONIC_DEAD dead" | tee -a "$OUTDIR/results.txt"

# === SONIC: HTTP status sweep for live subdomains ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- SONIC HTTP STATUS SWEEP ---" | tee -a "$OUTDIR/results.txt"
SONIC_INTERESTING=()
for sub in "${SONIC_LIVE[@]}"; do
  status=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' "https://$sub/" 2>/dev/null)
  echo "  $sub → $status" | tee -a "$OUTDIR/results.txt"
  # Collect interesting ones (not 301/302/403/000)
  if [[ "$status" != "301" && "$status" != "302" && "$status" != "403" && "$status" != "000" && "$status" != "404" ]]; then
    SONIC_INTERESTING+=("$sub|$status")
  fi
done

# === SONIC: Deep probe for interesting subdomains ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- SONIC DEEP PROBE (interesting hits) ---" | tee -a "$OUTDIR/results.txt"
for entry in "${SONIC_INTERESTING[@]:-}"; do
  [ -z "$entry" ] && continue
  sub="${entry%%|*}"
  status="${entry##*|}"
  safe=$(echo "$sub" | tr '.' '-')

  echo "" | tee -a "$OUTDIR/results.txt"
  echo "[$sub] Status: $status" | tee -a "$OUTDIR/results.txt"
  curl -sk --max-time 15 -D "$OUTDIR/sonic-${safe}-headers.txt" -o "$OUTDIR/sonic-${safe}-body.html" "https://$sub/" 2>/dev/null
  size=$(wc -c < "$OUTDIR/sonic-${safe}-body.html" 2>/dev/null)
  echo "  Body: ${size:-0} bytes" | tee -a "$OUTDIR/results.txt"
  head -5 "$OUTDIR/sonic-${safe}-headers.txt" 2>/dev/null | tee -a "$OUTDIR/results.txt"
  title=$(grep -oi '<title>[^<]*</title>' "$OUTDIR/sonic-${safe}-body.html" 2>/dev/null | head -1)
  [ -n "$title" ] && echo "  $title" | tee -a "$OUTDIR/results.txt"

  # TLS cert
  echo | openssl s_client -servername "$sub" -connect "$sub:443" 2>/dev/null | openssl x509 -noout -subject -issuer 2>/dev/null | tee -a "$OUTDIR/results.txt"
done

# === ARBY'S: DNS resolution sweep ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"
echo "--- ARBY'S DNS SWEEP ---" | tee -a "$OUTDIR/results.txt"

if [ -f "$INDIR/arbys-subdomains.txt" ]; then
  ARBYS_FILE="$INDIR/arbys-subdomains.txt"
else
  curl -s --max-time 60 "https://crt.sh/?q=%25.arbys.com&output=json" -o "$OUTDIR/arbys-certs.json" 2>/dev/null
  jq -r '.[].name_value' "$OUTDIR/arbys-certs.json" 2>/dev/null | sort -u | grep -v '\*' > "$OUTDIR/arbys-subdomains-fresh.txt" 2>/dev/null
  ARBYS_FILE="$OUTDIR/arbys-subdomains-fresh.txt"
  sleep 5
fi

ARBYS_LIVE=()
ARBYS_DEAD=0
while IFS= read -r sub; do
  [[ "$sub" == \** ]] && continue
  [[ "$sub" != *arbys.com ]] && continue

  a=$(dig +short "$sub" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  if [ -n "$a" ]; then
    cname=$(dig +short "$sub" CNAME @8.8.8.8 2>/dev/null | head -1)
    echo "LIVE: $sub  A: $a  CNAME: ${cname:-none}" | tee -a "$OUTDIR/results.txt"
    ARBYS_LIVE+=("$sub")
  else
    ARBYS_DEAD=$((ARBYS_DEAD + 1))
  fi
done < "$ARBYS_FILE"

echo "" | tee -a "$OUTDIR/results.txt"
echo "Arby's: ${#ARBYS_LIVE[@]} live, $ARBYS_DEAD dead" | tee -a "$OUTDIR/results.txt"

# === ARBY'S: HTTP status sweep ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- ARBY'S HTTP STATUS SWEEP ---" | tee -a "$OUTDIR/results.txt"
for sub in "${ARBYS_LIVE[@]}"; do
  status=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' "https://$sub/" 2>/dev/null)
  echo "  $sub → $status" | tee -a "$OUTDIR/results.txt"
done

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== PROBE COMPLETE ===" | tee -a "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
