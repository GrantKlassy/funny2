#!/bin/bash
# Corporate Portal and Franchisee Portal wildcard enumeration
# Discovered via BAM cert SANs (A33): *.corporateportal.dunkinbrands.com, *.franchisee.dunkinbrands.com
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/portal-enumeration-2026-04-13:/out:Z \
#   investigator bash /work/scripts/37-portal-enumeration.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== PORTAL WILDCARD ENUMERATION ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# === CT LOG SEARCH (find actual issued subdomain names) ===
echo "--- CT Log Search ---" | tee -a "$OUTDIR/results.txt"

echo "[corporateportal.dunkinbrands.com]" | tee -a "$OUTDIR/results.txt"
curl -s --max-time 45 "https://crt.sh/?q=%25.corporateportal.dunkinbrands.com&output=json" -o "$OUTDIR/corporateportal-certs.json" 2>/dev/null
if [ -f "$OUTDIR/corporateportal-certs.json" ]; then
  count=$(jq length "$OUTDIR/corporateportal-certs.json" 2>/dev/null)
  echo "  Certs found: ${count:-0}" | tee -a "$OUTDIR/results.txt"
  jq -r '.[].common_name' "$OUTDIR/corporateportal-certs.json" 2>/dev/null | sort -u | tee -a "$OUTDIR/results.txt"
  jq -r '.[].name_value' "$OUTDIR/corporateportal-certs.json" 2>/dev/null | sort -u | tee -a "$OUTDIR/results.txt"
fi
sleep 3

echo "" | tee -a "$OUTDIR/results.txt"
echo "[franchisee.dunkinbrands.com]" | tee -a "$OUTDIR/results.txt"
curl -s --max-time 45 "https://crt.sh/?q=%25.franchisee.dunkinbrands.com&output=json" -o "$OUTDIR/franchisee-certs.json" 2>/dev/null
if [ -f "$OUTDIR/franchisee-certs.json" ]; then
  count=$(jq length "$OUTDIR/franchisee-certs.json" 2>/dev/null)
  echo "  Certs found: ${count:-0}" | tee -a "$OUTDIR/results.txt"
  jq -r '.[].common_name' "$OUTDIR/franchisee-certs.json" 2>/dev/null | sort -u | tee -a "$OUTDIR/results.txt"
  jq -r '.[].name_value' "$OUTDIR/franchisee-certs.json" 2>/dev/null | sort -u | tee -a "$OUTDIR/results.txt"
fi
sleep 3

# === DNS SWEEP: Common subdomain prefixes ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- DNS Subdomain Sweep ---" | tee -a "$OUTDIR/results.txt"
PREFIXES=(
  "www" "app" "api" "portal" "login" "admin" "sso" "dev" "staging" "qa" "uat"
  "test" "prod" "reports" "training" "docs" "help" "support" "intranet" "hr"
  "ops" "supply" "menu" "inventory" "order" "store" "dashboard" "auth"
  "mail" "smtp" "ftp" "vpn" "remote" "cdn" "assets" "static" "media"
)

for scope in "corporateportal.dunkinbrands.com" "franchisee.dunkinbrands.com"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "[$scope] DNS sweep:" | tee -a "$OUTDIR/results.txt"
  # Also try root
  root_a=$(dig +short "$scope" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  root_cname=$(dig +short "$scope" CNAME @8.8.8.8 2>/dev/null | head -1)
  echo "  ROOT: A: ${root_a:-NXDOMAIN}  CNAME: ${root_cname:-none}" | tee -a "$OUTDIR/results.txt"

  for prefix in "${PREFIXES[@]}"; do
    fqdn="${prefix}.${scope}"
    a=$(dig +short "$fqdn" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
    if [ -n "$a" ]; then
      cname=$(dig +short "$fqdn" CNAME @8.8.8.8 2>/dev/null | head -1)
      echo "  LIVE: $fqdn  A: $a  CNAME: ${cname:-none}" | tee -a "$OUTDIR/results.txt"
    fi
  done
done

# === HTTP PROBE: Any that resolved ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- HTTP Probe of Discovered Subdomains ---" | tee -a "$OUTDIR/results.txt"
# Re-check root domains and probe
for scope in "corporateportal.dunkinbrands.com" "franchisee.dunkinbrands.com"; do
  a=$(dig +short "$scope" A @8.8.8.8 2>/dev/null | head -1)
  if [ -n "$a" ]; then
    echo "[$scope] HTTPS probe:" | tee -a "$OUTDIR/results.txt"
    status=$(curl -sk --max-time 15 -o /dev/null -w '%{http_code}' "https://$scope/" 2>/dev/null)
    echo "  Status: $status" | tee -a "$OUTDIR/results.txt"
    if [ "$status" != "000" ]; then
      curl -sk --max-time 15 -D "$OUTDIR/${scope}-headers.txt" -o "$OUTDIR/${scope}-body.html" "https://$scope/" 2>/dev/null
      size=$(wc -c < "$OUTDIR/${scope}-body.html" 2>/dev/null)
      echo "  Body: ${size:-0} bytes" | tee -a "$OUTDIR/results.txt"
      head -10 "$OUTDIR/${scope}-headers.txt" 2>/dev/null | tee -a "$OUTDIR/results.txt"
    fi
  fi
done

# === BAM PATH SWEEP (before Okta redirect kicks in) ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- BAM Path Sweep ---" | tee -a "$OUTDIR/results.txt"
BAM_PATHS=("/" "/api" "/portal" "/franchisee" "/corporate" "/dashboard" "/admin" "/login" "/health" "/status" "/favicon.ico" "/robots.txt" "/.well-known/security.txt")
for path in "${BAM_PATHS[@]}"; do
  status=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' "https://bam.dunkinbrands.com$path" 2>/dev/null)
  echo "  bam.dunkinbrands.com$path → $status" | tee -a "$OUTDIR/results.txt"
done

# === WAYBACK CDX ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Wayback CDX ---" | tee -a "$OUTDIR/results.txt"
for scope in "corporateportal.dunkinbrands.com" "franchisee.dunkinbrands.com" "bam.dunkinbrands.com"; do
  echo "[$scope]:" | tee -a "$OUTDIR/results.txt"
  curl -s --max-time 30 "http://web.archive.org/cdx/search/cdx?url=${scope}&matchType=domain&output=json&limit=20&fl=timestamp,original,statuscode,mimetype" -o "$OUTDIR/${scope}-wayback.json" 2>/dev/null
  jq -r '.[] | "\(.[0]) \(.[1]) \(.[2]) \(.[3])"' "$OUTDIR/${scope}-wayback.json" 2>/dev/null | tee -a "$OUTDIR/results.txt"
  sleep 2
done

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== PROBE COMPLETE ===" | tee -a "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
