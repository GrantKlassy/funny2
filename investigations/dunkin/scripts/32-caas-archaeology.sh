#!/bin/bash
# CAAS platform archaeology: fps, rbos, and the dead ELB
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/caas-archaeology-2026-04-13:/out:Z \
#   investigator bash /work/scripts/32-caas-archaeology.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== CAAS PLATFORM ARCHAEOLOGY ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

ELB="caas-prod-dunkinbrands-com-261297133.us-east-1.elb.amazonaws.com"

# === ELB DNS ===
echo "--- CAAS ELB DNS ---" | tee -a "$OUTDIR/results.txt"
echo "ELB: $ELB" | tee -a "$OUTDIR/results.txt"
dig +short "$ELB" A @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

# === FPS / RBOS current state ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- fps.dunkinbrands.com ---" | tee -a "$OUTDIR/results.txt"
dig +short "fps.dunkinbrands.com" CNAME @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
dig +short "fps.dunkinbrands.com" A @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

echo "--- rbos.dunkinbrands.com ---" | tee -a "$OUTDIR/results.txt"
dig +short "rbos.dunkinbrands.com" CNAME @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
dig +short "rbos.dunkinbrands.com" A @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

# === Check for CAAS variants ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- CAAS DNS Variants ---" | tee -a "$OUTDIR/results.txt"
CAAS_VARIANTS=(
  "caas.dunkinbrands.com"
  "caas-dev.dunkinbrands.com"
  "caas-staging.dunkinbrands.com"
  "caas-stg.dunkinbrands.com"
  "caas-qa.dunkinbrands.com"
  "caas-uat.dunkinbrands.com"
  "caas-preprod.dunkinbrands.com"
)
for domain in "${CAAS_VARIANTS[@]}"; do
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -1)
  cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
  if [ -n "$a" ] || [ -n "$cname" ]; then
    echo "LIVE  $domain → ${cname:-$a}" | tee -a "$OUTDIR/results.txt"
  else
    echo "DEAD  $domain" | tee -a "$OUTDIR/results.txt"
  fi
done

# === Wayback for fps ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Wayback: fps.dunkinbrands.com ---" | tee -a "$OUTDIR/results.txt"
http_code=$(curl -s --max-time 30 -o "$OUTDIR/wb-fps.json" -w '%{http_code}' \
  "https://web.archive.org/cdx/search/cdx?url=fps.dunkinbrands.com/*&output=json&limit=20&collapse=urlkey&fl=timestamp,original,statuscode,mimetype" 2>/dev/null)
echo "  HTTP: $http_code" | tee -a "$OUTDIR/results.txt"
if [ "$http_code" = "200" ] && [ -s "$OUTDIR/wb-fps.json" ]; then
  jq -r '.[] | "\(.[0]) \(.[2]) \(.[3]) \(.[1])"' "$OUTDIR/wb-fps.json" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt" || true
fi

sleep 2

# === Wayback for rbos ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Wayback: rbos.dunkinbrands.com ---" | tee -a "$OUTDIR/results.txt"
http_code=$(curl -s --max-time 30 -o "$OUTDIR/wb-rbos.json" -w '%{http_code}' \
  "https://web.archive.org/cdx/search/cdx?url=rbos.dunkinbrands.com/*&output=json&limit=20&collapse=urlkey&fl=timestamp,original,statuscode,mimetype" 2>/dev/null)
echo "  HTTP: $http_code" | tee -a "$OUTDIR/results.txt"
if [ "$http_code" = "200" ] && [ -s "$OUTDIR/wb-rbos.json" ]; then
  jq -r '.[] | "\(.[0]) \(.[2]) \(.[3]) \(.[1])"' "$OUTDIR/wb-rbos.json" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt" || true
fi

sleep 2

# === Wayback for the ELB hostname itself ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Wayback: CAAS ELB ---" | tee -a "$OUTDIR/results.txt"
http_code=$(curl -s --max-time 30 -o "$OUTDIR/wb-caas-elb.json" -w '%{http_code}' \
  "https://web.archive.org/cdx/search/cdx?url=caas-prod-dunkinbrands-com*&output=json&limit=20&collapse=urlkey" 2>/dev/null)
echo "  HTTP: $http_code" | tee -a "$OUTDIR/results.txt"
if [ "$http_code" = "200" ] && [ -s "$OUTDIR/wb-caas-elb.json" ]; then
  cat "$OUTDIR/wb-caas-elb.json" | head -20 | tee -a "$OUTDIR/results.txt" || true
fi

# === Whois on ELB IPs ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- ELB IP Whois ---" | tee -a "$OUTDIR/results.txt"
elb_ips=$(dig +short "$ELB" A @8.8.8.8 2>/dev/null | head -3)
for ip in $elb_ips; do
  echo "[$ip]:" | tee -a "$OUTDIR/results.txt"
  whois "$ip" 2>/dev/null | grep -iE 'OrgName|NetRange|CIDR' | tee -a "$OUTDIR/results.txt" || true
done

# === CT log search for CAAS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- crt.sh: caas*.dunkinbrands.com ---" | tee -a "$OUTDIR/results.txt"
http_code=$(curl -s --max-time 45 -o "$OUTDIR/crtsh-caas.json" -w '%{http_code}' \
  "https://crt.sh/?q=caas%25.dunkinbrands.com&output=json" 2>/dev/null)
echo "  HTTP: $http_code" | tee -a "$OUTDIR/results.txt"
if [ "$http_code" = "200" ] && [ -s "$OUTDIR/crtsh-caas.json" ]; then
  count=$(jq length "$OUTDIR/crtsh-caas.json" 2>/dev/null || echo 0)
  echo "  Entries: $count" | tee -a "$OUTDIR/results.txt"
  jq -r '.[].common_name // empty' "$OUTDIR/crtsh-caas.json" 2>/dev/null | sort -u | tee -a "$OUTDIR/results.txt"
fi

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
echo "Completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
