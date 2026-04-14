#!/bin/bash
# SWI mystery service deep probe across all environments
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/swi-mystery-2026-04-13:/out:Z \
#   investigator bash /work/scripts/19-swi-mystery-probe.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== SWI MYSTERY SERVICE DEEP PROBE ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

SWI_HOSTS=(
  "swi.prod.ddmprod.dunkindonuts.com"
  "swi.preprod.ddmprod.dunkindonuts.com"
  "swi.stage.ddmprod.dunkindonuts.com"
  "swi.dev.ddmdev.dunkindonuts.com"
  "swi.dlt-dev.ddmdev.dunkindonuts.com"
  "swi.dlt-qa.ddmdev.dunkindonuts.com"
  "swi.qa.ddmdev.dunkindonuts.com"
)

# === DNS RESOLUTION ===
echo "--- DNS Resolution ---" | tee -a "$OUTDIR/results.txt"
LIVE_HOSTS=()
for host in "${SWI_HOSTS[@]}"; do
  a=$(dig +short "$host" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$host" CNAME @8.8.8.8 2>/dev/null | head -1)
  if [ -n "$cname" ] || [ -n "$a" ]; then
    echo "LIVE  $host → CNAME: ${cname:-none} → A: ${a:-none}" | tee -a "$OUTDIR/results.txt"
    LIVE_HOSTS+=("$host")
  else
    echo "DEAD  $host" | tee -a "$OUTDIR/results.txt"
  fi
done

# === HTTP METHOD SWEEP ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- HTTP Method Sweep (/) per host ---" | tee -a "$OUTDIR/results.txt"
for host in "${LIVE_HOSTS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "[$host]" | tee -a "$OUTDIR/results.txt"
  for method in GET POST HEAD OPTIONS PUT DELETE PATCH; do
    result=$(curl -sk --max-time 10 -X "$method" -o /dev/null -w '%{http_code} %{size_download}' "https://$host/" 2>/dev/null)
    echo "  $method / → $result" | tee -a "$OUTDIR/results.txt"
  done
done

# === PATH ENUMERATION (all live hosts) ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Path Enumeration ---" | tee -a "$OUTDIR/results.txt"
PATHS=(
  "/" "/api" "/api/v1" "/api/v2"
  "/health" "/healthcheck" "/status" "/version" "/info"
  "/swagger-ui" "/swagger-ui.html" "/v2/api-docs" "/v3/api-docs"
  "/actuator" "/actuator/health" "/actuator/info"
  "/login" "/auth" "/token" "/oauth" "/callback"
  "/webhook" "/notify" "/push" "/message" "/send"
  "/swi" "/SWI" "/config" "/settings"
  "/admin" "/console" "/dashboard"
  "/.well-known/openid-configuration"
)

for host in "${LIVE_HOSTS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "[$host] path sweep:" | tee -a "$OUTDIR/results.txt"
  for path in "${PATHS[@]}"; do
    result=$(curl -sk --max-time 8 -o /dev/null -w '%{http_code} %{size_download} %{content_type}' "https://$host$path" 2>/dev/null)
    status=$(echo "$result" | awk '{print $1}')
    size=$(echo "$result" | awk '{print $2}')
    ctype=$(echo "$result" | awk '{print $3}')
    # Only print non-000 responses
    if [ "$status" != "000" ]; then
      echo "  $path → $status (${size}B) [$ctype]" | tee -a "$OUTDIR/results.txt"
    fi

    # Capture bodies for 200 responses
    if [ "$status" = "200" ]; then
      safename=$(echo "${host}${path}" | tr '/.:-' '_')
      curl -sk --max-time 10 -D "$OUTDIR/${safename}.headers" "https://$host$path" > "$OUTDIR/${safename}.body" 2>/dev/null || true
    fi
  done
done

# === FULL HEADERS on prod vs dev ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Full Headers Comparison (prod vs dev) ---" | tee -a "$OUTDIR/results.txt"
for host in "swi.prod.ddmprod.dunkindonuts.com" "swi.dev.ddmdev.dunkindonuts.com"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "[$host] GET / headers:" | tee -a "$OUTDIR/results.txt"
  curl -sk --max-time 10 -I "https://$host/" 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "FAILED" | tee -a "$OUTDIR/results.txt"
done

# === TLS CERT COMPARISON ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- TLS Certificate Comparison ---" | tee -a "$OUTDIR/results.txt"
for host in "swi.prod.ddmprod.dunkindonuts.com" "swi.dev.ddmdev.dunkindonuts.com"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "[$host] cert:" | tee -a "$OUTDIR/results.txt"
  timeout 10 openssl s_client -connect "$host:443" -servername "$host" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "TLS FAILED" | tee -a "$OUTDIR/results.txt"
done

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
echo "Completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
