#!/bin/bash
# QA/Dev environment analysis: what leaks when Akamai isn't in front?
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin:/work/investigations/dunkin:Z \
#   -v ./investigations/dunkin/artifacts/qa-dev-environments-2026-04-13:/out:Z \
#   investigator bash /work/investigations/dunkin/scripts/13-qa-dev-environments.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== QA/DEV ENVIRONMENT ANALYSIS ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

ENVS=("www.dunkindonuts.com" "dev2.dunkindonuts.com" "qa.dunkindonuts.com" "qa2.dunkindonuts.com" "staging.dunkindonuts.com" "staging3.dunkindonuts.com" "uat.dunkindonuts.com")

# === DNS RESOLUTION — confirm which bypass Akamai ===
echo "--- DNS Resolution (Akamai vs Direct) ---" | tee -a "$OUTDIR/results.txt"
for domain in "${ENVS[@]}"; do
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
  if [ -n "$cname" ]; then
    if echo "$cname" | grep -qi "akamai\|edgekey\|edgesuite"; then
      echo "AKAMAI  $domain → $cname → $a" | tee -a "$OUTDIR/results.txt"
    elif echo "$cname" | grep -qi "cloudfront\|amazonaws"; then
      echo "AWS     $domain → $cname → $a" | tee -a "$OUTDIR/results.txt"
    else
      echo "OTHER   $domain → $cname → $a" | tee -a "$OUTDIR/results.txt"
    fi
  elif [ -n "$a" ]; then
    echo "DIRECT  $domain → $a" | tee -a "$OUTDIR/results.txt"
  else
    echo "DEAD    $domain" | tee -a "$OUTDIR/results.txt"
  fi
done

# === FULL HEADER COMPARISON ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Full Response Headers (GET /) ---" | tee -a "$OUTDIR/results.txt"
for domain in "${ENVS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> $domain" | tee -a "$OUTDIR/results.txt"
  headers=$(curl -sI --max-time 10 "https://$domain/" 2>/dev/null || echo "CONNECTION FAILED")
  echo "$headers" | tee -a "$OUTDIR/results.txt"

  # Extract key headers for comparison (|| true to avoid set -e killing on no match)
  server=$(echo "$headers" | grep -i "^server:" | head -1 || true)
  powered=$(echo "$headers" | grep -i "^x-powered-by:" | head -1 || true)
  debug=$(echo "$headers" | grep -iE "^x-debug|^x-request-id|^x-correlation" | head -3 || true)
  akamai=$(echo "$headers" | grep -iE "^x-akamai|^x-cache|^x-true-cache" | head -3 || true)
  security=$(echo "$headers" | grep -iE "^x-content-type|^x-frame-options|^x-xss|^strict-transport|^content-security-policy" | head -5 || true)
  cookies=$(echo "$headers" | grep -i "^set-cookie:" | head -3 || true)

  echo "  [Server] ${server:-MISSING}" | tee -a "$OUTDIR/results.txt"
  echo "  [X-Powered-By] ${powered:-MISSING}" | tee -a "$OUTDIR/results.txt"
  echo "  [Debug headers] ${debug:-NONE}" | tee -a "$OUTDIR/results.txt"
  echo "  [Akamai headers] ${akamai:-NONE}" | tee -a "$OUTDIR/results.txt"
  echo "  [Security headers] ${security:-NONE}" | tee -a "$OUTDIR/results.txt"
  echo "  [Cookies] ${cookies:-NONE}" | tee -a "$OUTDIR/results.txt"
done

# === ERROR PAGE COMPARISON ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Error Page Comparison (404) ---" | tee -a "$OUTDIR/results.txt"
for domain in "${ENVS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> $domain/nonexistent-probe-test" | tee -a "$OUTDIR/results.txt"
  response=$(curl -s --max-time 10 -w "\n---HTTP_CODE:%{http_code}---" "https://$domain/nonexistent-probe-test" 2>/dev/null | tail -50)
  echo "$response" | tee -a "$OUTDIR/results.txt"
done

# === WHOIS UAT IP ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Whois: UAT IP 216.255.76.18 ---" | tee -a "$OUTDIR/results.txt"
whois 216.255.76.18 2>/dev/null | grep -iE "^(orgname|org-name|netname|descr|country|cidr|netrange|organization|owner|address)" | tee -a "$OUTDIR/results.txt" || true

# Reverse DNS
echo "" | tee -a "$OUTDIR/results.txt"
echo ">> Reverse DNS:" | tee -a "$OUTDIR/results.txt"
dig +short -x 216.255.76.18 @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

# Also check QA IP
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Whois: QA IP 52.71.129.172 ---" | tee -a "$OUTDIR/results.txt"
whois 52.71.129.172 2>/dev/null | grep -iE "^(orgname|org-name|netname|descr|country|cidr|netrange|organization|owner)" | tee -a "$OUTDIR/results.txt" || true

# === WELL-KNOWN ENDPOINT SWEEP (QA vs WWW) ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Well-Known Endpoints: QA vs WWW ---" | tee -a "$OUTDIR/results.txt"

WELL_KNOWN=(
  "/.well-known/openid-configuration"
  "/.well-known/apple-app-site-association"
  "/.well-known/assetlinks.json"
  "/.well-known/security.txt"
  "/robots.txt"
  "/sitemap.xml"
  "/favicon.ico"
  "/health"
  "/status"
  "/version"
)

for path in "${WELL_KNOWN[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> PATH: $path" | tee -a "$OUTDIR/results.txt"
  for domain in "www.dunkindonuts.com" "qa.dunkindonuts.com"; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "https://$domain$path" 2>/dev/null || echo "FAIL")
    size=$(curl -s -o /dev/null -w '%{size_download}' --max-time 8 "https://$domain$path" 2>/dev/null || echo "0")
    echo "  $domain → $code (${size}B)" | tee -a "$OUTDIR/results.txt"
  done
done

# === TLS CERT COMPARISON ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- TLS Certificate Comparison ---" | tee -a "$OUTDIR/results.txt"
for domain in "${ENVS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> $domain" | tee -a "$OUTDIR/results.txt"
  cert_info=$(echo | timeout 10 openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | head -20 || true)
  if [ -n "$cert_info" ]; then
    echo "$cert_info" | tee -a "$OUTDIR/results.txt"
  else
    echo "  CERT UNAVAILABLE (connection failed or no cert)" | tee -a "$OUTDIR/results.txt"
  fi
done

# === BONUS: Check if any dev environments leak server version info ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Server Fingerprinting (OPTIONS method) ---" | tee -a "$OUTDIR/results.txt"
for domain in "${ENVS[@]}"; do
  echo ">> OPTIONS $domain" | tee -a "$OUTDIR/results.txt"
  curl -sI -X OPTIONS --max-time 8 "https://$domain/" 2>/dev/null | grep -iE "^(HTTP|server|allow|access-control|x-powered)" | tee -a "$OUTDIR/results.txt" || true
done

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
