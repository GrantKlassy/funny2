#!/bin/bash
# Deep probe of legacy services that script 12 missed or only partially hit
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/legacy-deep-2026-04-13:/out:Z \
#   investigator bash /work/scripts/25-legacy-deep-probe.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== LEGACY SERVICES DEEP PROBE ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# Helper: full probe of a single target
probe_target() {
  local domain="$1"
  local label="$2"

  echo "========================================" | tee -a "$OUTDIR/results.txt"
  echo "TARGET: $domain ($label)" | tee -a "$OUTDIR/results.txt"
  echo "========================================" | tee -a "$OUTDIR/results.txt"

  # DNS
  local a cname
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
  echo "  DNS → CNAME: ${cname:-none} A: ${a:-none}" | tee -a "$OUTDIR/results.txt"

  if [ -z "$a" ] && [ -z "$cname" ]; then
    echo "  DEAD (NXDOMAIN)" | tee -a "$OUTDIR/results.txt"
    echo "" | tee -a "$OUTDIR/results.txt"
    return
  fi

  # HTTP method sweep
  echo "  Methods:" | tee -a "$OUTDIR/results.txt"
  for method in GET POST HEAD OPTIONS PUT DELETE; do
    result=$(curl -sk --max-time 10 -X "$method" -o /dev/null -w '%{http_code} %{size_download}' "https://$domain/" 2>/dev/null)
    echo "    $method → $result" | tee -a "$OUTDIR/results.txt"
  done

  # Also try HTTP
  http_status=$(curl -s --max-time 8 -o /dev/null -w '%{http_code}' "http://$domain/" 2>/dev/null)
  echo "    GET (HTTP) → $http_status" | tee -a "$OUTDIR/results.txt"

  # Full headers
  echo "  Headers (GET /):" | tee -a "$OUTDIR/results.txt"
  curl -sk --max-time 10 -I "https://$domain/" 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "    FAILED" | tee -a "$OUTDIR/results.txt"

  # Capture body
  local safename
  safename=$(echo "$domain" | tr '.' '_')
  curl -sk --max-time 10 -D "$OUTDIR/${safename}.headers" "https://$domain/" > "$OUTDIR/${safename}.body" 2>/dev/null || true

  # TLS cert
  echo "  TLS Cert:" | tee -a "$OUTDIR/results.txt"
  timeout 10 openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "    TLS FAILED" | tee -a "$OUTDIR/results.txt"

  echo "" | tee -a "$OUTDIR/results.txt"
}

# === SMARTSOLVE (OPTIONS was 200 — investigate) ===
probe_target "smartsolve.dunkinbrands.com" "SmartSolve EQMS"

echo "--- SmartSolve: OPTIONS response body ---" | tee -a "$OUTDIR/results.txt"
curl -sk --max-time 10 -X OPTIONS -D "$OUTDIR/smartsolve-options.headers" "https://smartsolve.dunkinbrands.com/" > "$OUTDIR/smartsolve-options.body" 2>/dev/null || true
cat "$OUTDIR/smartsolve-options.headers" 2>/dev/null | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

echo "--- SmartSolve: path sweep ---" | tee -a "$OUTDIR/results.txt"
for path in "/SmartProd" "/SmartProd/login.aspx" "/login" "/api" "/swagger-ui" "/DesktopModules"; do
  status=$(curl -sk --max-time 8 -o /dev/null -w '%{http_code}' "https://smartsolve.dunkinbrands.com$path" 2>/dev/null)
  echo "  $path → $status" | tee -a "$OUTDIR/results.txt"
done

# === BAM ===
probe_target "bam.dunkinbrands.com" "BAM (unknown)"

# === STS (Security Token Service) ===
probe_target "sts.dunkinbrands.com" "STS (Security Token Service)"

echo "--- STS: Federation metadata ---" | tee -a "$OUTDIR/results.txt"
for path in "/adfs/ls" "/adfs/services/trust/mex" "/FederationMetadata/2007-06/FederationMetadata.xml" "/.well-known/openid-configuration" "/adfs/.well-known/openid-configuration"; do
  status=$(curl -sk --max-time 8 -o /dev/null -w '%{http_code} %{size_download}' "https://sts.dunkinbrands.com$path" 2>/dev/null)
  echo "  $path → $status" | tee -a "$OUTDIR/results.txt"
  if echo "$status" | grep -q "^200 "; then
    safename=$(echo "$path" | tr '/.:-' '_')
    curl -sk --max-time 10 "https://sts.dunkinbrands.com$path" > "$OUTDIR/sts${safename}.body" 2>/dev/null || true
  fi
done

# === WSAPI ===
probe_target "wsapi.dunkinbrands.com" "Web Service API"

# === CITRIX ===
probe_target "citrix.dunkinbrands.com" "Citrix Gateway"

# === SSLVPN ===
probe_target "sslvpn.dunkinbrands.com" "SSL VPN"

# === PLMSUPPLIER ===
probe_target "plmsupplier.dunkinbrands.com" "PLM Supplier Portal"

echo "--- PLM Supplier path sweep ---" | tee -a "$OUTDIR/results.txt"
for path in "/supplier" "/login" "/api" "/portal" "/PLM"; do
  status=$(curl -sk --max-time 8 -o /dev/null -w '%{http_code}' "https://plmsupplier.dunkinbrands.com$path" 2>/dev/null)
  echo "  $path → $status" | tee -a "$OUTDIR/results.txt"
done

# === AFM ===
probe_target "afm.dunkinbrands.com" "AFM (unknown)"

# === FLQ-PROD-IDP (Identity Provider) ===
probe_target "flq-prod-idp.dunkinbrands.com" "FLQ Identity Provider"

echo "--- FLQ-IDP: OIDC/SAML discovery ---" | tee -a "$OUTDIR/results.txt"
for path in "/.well-known/openid-configuration" "/adfs/ls" "/adfs/services/trust/mex" "/FederationMetadata/2007-06/FederationMetadata.xml" "/saml/metadata" "/oauth2/authorize" "/login"; do
  status=$(curl -sk --max-time 8 -o /dev/null -w '%{http_code} %{size_download}' "https://flq-prod-idp.dunkinbrands.com$path" 2>/dev/null)
  echo "  $path → $status" | tee -a "$OUTDIR/results.txt"
  if echo "$status" | grep -q "^200 "; then
    safename=$(echo "$path" | tr '/.:-' '_')
    curl -sk --max-time 10 "https://flq-prod-idp.dunkinbrands.com$path" > "$OUTDIR/flq-idp${safename}.body" 2>/dev/null || true
  fi
done

# === THECENTER (CloudFront) ===
probe_target "thecenter.dunkinbrands.com" "The Center (Learning Portal)"

# === WHOIS on 74.199.217.x subnet ===
echo "========================================" | tee -a "$OUTDIR/results.txt"
echo "SUBNET INVESTIGATION: 74.199.217.0/24" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"
echo "(flq-prod-idp at .23, smartsolve at .32)" | tee -a "$OUTDIR/results.txt"
whois 74.199.217.23 2>/dev/null | grep -iE 'OrgName|OrgId|NetRange|CIDR|Country|City|StateProv|Descr|Organization' | tee -a "$OUTDIR/results.txt" || echo "whois FAILED" | tee -a "$OUTDIR/results.txt"

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
echo "Completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
