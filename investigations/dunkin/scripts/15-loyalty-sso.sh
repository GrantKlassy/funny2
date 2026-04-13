#!/bin/bash
# SSO and loyalty service probing: discovery endpoints, provider fingerprinting
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/loyalty-sso-2026-04-13:/out:Z \
#   investigator bash /work/scripts/15-loyalty-sso.sh
set -euo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== LOYALTY & SSO PROBING ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

SSO_HOSTS=("ssoprd.dunkindonuts.com" "ssostg.dunkindonuts.com" "social-ssoprd.dunkindonuts.com" "social-ssopreprod.dunkindonuts.com" "social-ssostg.dunkindonuts.com")

# === DNS RESOLUTION ===
echo "--- DNS Resolution ---" | tee -a "$OUTDIR/results.txt"
for host in "${SSO_HOSTS[@]}" "loyalty.dunkindonuts.com"; do
  a=$(dig +short "$host" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$host" CNAME @8.8.8.8 2>/dev/null | head -1)
  echo "$host → CNAME: ${cname:-none} A: ${a:-unresolved}" | tee -a "$OUTDIR/results.txt"
done

# === SSO BASELINE ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- SSO Baseline Headers ---" | tee -a "$OUTDIR/results.txt"
for host in "${SSO_HOSTS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> $host (GET /)" | tee -a "$OUTDIR/results.txt"
  curl -sI --max-time 10 "https://$host/" 2>/dev/null | tee -a "$OUTDIR/results.txt"
  echo ">> Body:" | tee -a "$OUTDIR/results.txt"
  curl -sL --max-time 10 "https://$host/" 2>/dev/null | head -30 | tee -a "$OUTDIR/results.txt"
done

# === SSO DISCOVERY ENDPOINTS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- SSO Discovery Endpoints ---" | tee -a "$OUTDIR/results.txt"

DISCOVERY_PATHS=(
  "/.well-known/openid-configuration"
  "/.well-known/oauth-authorization-server"
  "/saml/metadata"
  "/FederationMetadata/2007-06/FederationMetadata.xml"
  "/adfs/ls"
  "/adfs/.well-known/openid-configuration"
  "/oauth2/authorize"
  "/oauth2/token"
  "/oauth2/.well-known/openid-configuration"
  "/auth/realms/master/.well-known/openid-configuration"
  "/.well-known/webfinger"
  "/login"
  "/Login"
  "/Account/Login"
)

for host in "${SSO_HOSTS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> Discovery sweep: $host" | tee -a "$OUTDIR/results.txt"
  for path in "${DISCOVERY_PATHS[@]}"; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "https://$host$path" 2>/dev/null || echo "FAIL")
    if [ "$code" != "000" ] && [ "$code" != "FAIL" ]; then
      echo "  $path → $code" | tee -a "$OUTDIR/results.txt"
      if [ "$code" = "200" ]; then
        echo "  [BODY]:" | tee -a "$OUTDIR/results.txt"
        curl -s --max-time 8 "https://$host$path" 2>/dev/null | head -40 | tee -a "$OUTDIR/results.txt"
        echo "  [/BODY]" | tee -a "$OUTDIR/results.txt"
      fi
    fi
  done
done

# === SOCIAL-SSO User-Agent comparison (403 targets) ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Social-SSO: User-Agent Comparison ---" | tee -a "$OUTDIR/results.txt"
MOBILE_UA="Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
DESKTOP_UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

for host in "social-ssoprd.dunkindonuts.com" "social-ssopreprod.dunkindonuts.com" "social-ssostg.dunkindonuts.com"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> $host" | tee -a "$OUTDIR/results.txt"
  for ua_name in "mobile" "desktop" "curl"; do
    if [ "$ua_name" = "mobile" ]; then
      code=$(curl -s -o /dev/null -w '%{http_code}' -A "$MOBILE_UA" --max-time 8 "https://$host/" 2>/dev/null || echo "FAIL")
    elif [ "$ua_name" = "desktop" ]; then
      code=$(curl -s -o /dev/null -w '%{http_code}' -A "$DESKTOP_UA" --max-time 8 "https://$host/" 2>/dev/null || echo "FAIL")
    else
      code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "https://$host/" 2>/dev/null || echo "FAIL")
    fi
    echo "  UA=$ua_name → $code" | tee -a "$OUTDIR/results.txt"
  done
done

# === LOYALTY SERVICE ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Loyalty Service: loyalty.dunkindonuts.com ---" | tee -a "$OUTDIR/results.txt"

echo ">> Headers (GET /):" | tee -a "$OUTDIR/results.txt"
curl -sI --max-time 10 "https://loyalty.dunkindonuts.com/" 2>/dev/null | tee -a "$OUTDIR/results.txt"

echo ">> Body (first 40 lines):" | tee -a "$OUTDIR/results.txt"
curl -sL --max-time 10 "https://loyalty.dunkindonuts.com/" 2>/dev/null | head -40 | tee -a "$OUTDIR/results.txt"

LOYALTY_PATHS=("/api" "/api/v1" "/health" "/status" "/swagger-ui" "/v2/api-docs" "/v3/api-docs" "/graphql" "/login" "/.well-known/openid-configuration")
echo "" | tee -a "$OUTDIR/results.txt"
echo ">> Path sweep:" | tee -a "$OUTDIR/results.txt"
for path in "${LOYALTY_PATHS[@]}"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "https://loyalty.dunkindonuts.com$path" 2>/dev/null || echo "FAIL")
  if [ "$code" != "000" ] && [ "$code" != "FAIL" ]; then
    echo "  $path → $code" | tee -a "$OUTDIR/results.txt"
  fi
done

# === TLS CERTS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- TLS Certificates ---" | tee -a "$OUTDIR/results.txt"
for host in "${SSO_HOSTS[@]}" "loyalty.dunkindonuts.com"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> $host" | tee -a "$OUTDIR/results.txt"
  echo | timeout 10 openssl s_client -connect "$host:443" -servername "$host" 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "  TLS failed" | tee -a "$OUTDIR/results.txt"
done

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
