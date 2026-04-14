#!/bin/bash
# Deep probe: star.dunkinbrands.com, k.prod.ddmprod, auth0-stg
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/mystery-services-deep-2026-04-13:/out:Z \
#   investigator bash /work/scripts/20-mystery-services-deep.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== MYSTERY SERVICES DEEP PROBE ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# ============================================================
# STAR.DUNKINBRANDS.COM
# ============================================================
echo "========================================" | tee -a "$OUTDIR/results.txt"
echo "TARGET: star.dunkinbrands.com" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"

STAR="star.dunkinbrands.com"

# DNS
echo "--- DNS ---" | tee -a "$OUTDIR/results.txt"
dig +short "$STAR" A @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
dig +short "$STAR" CNAME @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

# Full GET body capture (never done before!)
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- GET / (full response) ---" | tee -a "$OUTDIR/results.txt"
curl -sk --max-time 15 -D "$OUTDIR/star-root.headers" "https://$STAR/" > "$OUTDIR/star-root.body" 2>/dev/null
star_status=$(head -1 "$OUTDIR/star-root.headers" 2>/dev/null || echo "FAILED")
star_size=$(wc -c < "$OUTDIR/star-root.body" 2>/dev/null || echo 0)
echo "  Status: $star_status" | tee -a "$OUTDIR/results.txt"
echo "  Body size: ${star_size} bytes" | tee -a "$OUTDIR/results.txt"
echo "  Body preview:" | tee -a "$OUTDIR/results.txt"
head -c 2000 "$OUTDIR/star-root.body" 2>/dev/null | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# Full headers
echo "--- Full Headers ---" | tee -a "$OUTDIR/results.txt"
cat "$OUTDIR/star-root.headers" 2>/dev/null | tee -a "$OUTDIR/results.txt"

# Cookie inspection
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Cookies ---" | tee -a "$OUTDIR/results.txt"
curl -sk --max-time 10 -c - "https://$STAR/" 2>/dev/null | grep -v '^#' | tee -a "$OUTDIR/results.txt" || echo "no cookies" | tee -a "$OUTDIR/results.txt"

# HTTP method sweep
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Method Sweep ---" | tee -a "$OUTDIR/results.txt"
for method in GET POST HEAD OPTIONS PUT DELETE PATCH; do
  result=$(curl -sk --max-time 10 -X "$method" -o /dev/null -w '%{http_code} %{size_download}' "https://$STAR/" 2>/dev/null)
  echo "  $method / → $result" | tee -a "$OUTDIR/results.txt"
done

# POST with various content types
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- POST with Content-Types ---" | tee -a "$OUTDIR/results.txt"
for ct in "application/json" "application/xml" "application/x-www-form-urlencoded" "text/plain"; do
  status=$(curl -sk --max-time 10 -X POST -H "Content-Type: $ct" -d '{}' -o /dev/null -w '%{http_code} %{size_download}' "https://$STAR/" 2>/dev/null)
  echo "  POST (${ct}) → $status" | tee -a "$OUTDIR/results.txt"
done

# Path fuzzing
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Path Fuzzing ---" | tee -a "$OUTDIR/results.txt"
STAR_PATHS=(
  "/star" "/Star" "/STAR" "/api" "/api/star" "/api/v1"
  "/v1/star" "/rewards" "/points" "/balance" "/account"
  "/check" "/register" "/login" "/status" "/health"
  "/stars" "/loyalty" "/members" "/cardNumber"
  "/swagger-ui" "/v2/api-docs" "/actuator"
)
for path in "${STAR_PATHS[@]}"; do
  result=$(curl -sk --max-time 8 -o /dev/null -w '%{http_code} %{size_download}' "https://$STAR$path" 2>/dev/null)
  status=$(echo "$result" | awk '{print $1}')
  if [ "$status" != "000" ]; then
    echo "  $path → $result" | tee -a "$OUTDIR/results.txt"
  fi
  if [ "$status" = "200" ]; then
    safename=$(echo "$path" | tr '/' '_' | sed 's/^_//')
    curl -sk --max-time 10 "https://$STAR$path" > "$OUTDIR/star-${safename}.body" 2>/dev/null || true
  fi
done

# TLS cert
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- TLS Certificate ---" | tee -a "$OUTDIR/results.txt"
timeout 10 openssl s_client -connect "$STAR:443" -servername "$STAR" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "TLS FAILED" | tee -a "$OUTDIR/results.txt"

# Also check star-stg
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- star-stg.dunkinbrands.com DNS ---" | tee -a "$OUTDIR/results.txt"
dig +short "star-stg.dunkinbrands.com" A @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
stg_status=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' "https://star-stg.dunkinbrands.com/" 2>/dev/null)
echo "  GET / → $stg_status" | tee -a "$OUTDIR/results.txt"

# ============================================================
# K.PROD.DDMPROD.DUNKINDONUTS.COM
# ============================================================
echo "" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"
echo "TARGET: k.prod.ddmprod.dunkindonuts.com" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"

K="k.prod.ddmprod.dunkindonuts.com"

# Multi-resolver DNS
echo "--- DNS (multi-resolver) ---" | tee -a "$OUTDIR/results.txt"
for ns in 8.8.8.8 1.1.1.1 9.9.9.9 208.67.222.222; do
  a=$(dig +short "$K" A @"$ns" 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$K" CNAME @"$ns" 2>/dev/null | head -1)
  echo "  @$ns → A: ${a:-none}, CNAME: ${cname:-none}" | tee -a "$OUTDIR/results.txt"
done

# Try via Host header against Akamai edge (ulink resolves to Akamai)
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Host header trick via ulink Akamai edge ---" | tee -a "$OUTDIR/results.txt"
ULINK_IP=$(dig +short "ulink.prod.ddmprod.dunkindonuts.com" A @8.8.8.8 2>/dev/null | tail -1)
echo "  ulink edge IP: ${ULINK_IP:-unresolved}" | tee -a "$OUTDIR/results.txt"
if [ -n "$ULINK_IP" ]; then
  for host_header in "$K" "k.prod.ddmprod.dunkindonuts.com"; do
    result=$(curl -sk --max-time 10 --resolve "$host_header:443:$ULINK_IP" -o /dev/null -w '%{http_code} %{size_download}' "https://$host_header/" 2>/dev/null)
    echo "  curl --resolve $host_header:443:$ULINK_IP → $result" | tee -a "$OUTDIR/results.txt"
    if [ "$(echo "$result" | awk '{print $1}')" != "000" ]; then
      curl -sk --max-time 10 --resolve "$host_header:443:$ULINK_IP" -D "$OUTDIR/k-via-akamai.headers" "https://$host_header/" > "$OUTDIR/k-via-akamai.body" 2>/dev/null || true
    fi
  done
fi

# ============================================================
# AUTH0-STG.DUNKINDONUTS.COM
# ============================================================
echo "" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"
echo "TARGET: auth0-stg.dunkindonuts.com" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"

AUTH0="auth0-stg.dunkindonuts.com"

# DNS
echo "--- DNS ---" | tee -a "$OUTDIR/results.txt"
dig +short "$AUTH0" CNAME @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
dig +short "$AUTH0" A @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

# TLS cert
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- TLS Certificate ---" | tee -a "$OUTDIR/results.txt"
timeout 10 openssl s_client -connect "$AUTH0:443" -servername "$AUTH0" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "TLS FAILED" | tee -a "$OUTDIR/results.txt"

# Auth0/OIDC endpoints
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Auth0/OIDC Endpoints ---" | tee -a "$OUTDIR/results.txt"
AUTH0_PATHS=(
  "/"
  "/.well-known/openid-configuration"
  "/.well-known/jwks.json"
  "/authorize"
  "/oauth/token"
  "/userinfo"
  "/v2/"
  "/api/v2/"
  "/login"
  "/logout"
  "/dbconnections/signup"
  "/passwordless/start"
  "/mfa/challenge"
)
for path in "${AUTH0_PATHS[@]}"; do
  result=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code} %{size_download} %{content_type}' "https://$AUTH0$path" 2>/dev/null)
  status=$(echo "$result" | awk '{print $1}')
  echo "  $path → $result" | tee -a "$OUTDIR/results.txt"
  if [ "$status" = "200" ]; then
    safename=$(echo "$path" | tr '/.:-' '_')
    curl -sk --max-time 10 "https://$AUTH0$path" > "$OUTDIR/auth0${safename}.body" 2>/dev/null || true
  fi
done

# Full headers
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Full Headers (GET /) ---" | tee -a "$OUTDIR/results.txt"
curl -sk --max-time 10 -I "https://$AUTH0/" 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "FAILED" | tee -a "$OUTDIR/results.txt"

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
echo "Completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
