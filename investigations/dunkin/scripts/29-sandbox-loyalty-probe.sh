#!/bin/bash
# Sandbox environment probing: loyalty, rewards, OATS, Splunk, Swagger
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/sandbox-loyalty-2026-04-13:/out:Z \
#   investigator bash /work/scripts/29-sandbox-loyalty-probe.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== SANDBOX ENVIRONMENT PROBE ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

TARGETS=(
  "loyalty-api.sandbox.dunkindonuts.com|Loyalty API"
  "loyalty-mock-api.sandbox.dunkindonuts.com|Loyalty Mock API"
  "rewards-api.sandbox.dunkindonuts.com|Rewards API"
  "oats-api.sandbox.dunkindonuts.com|OATS API"
  "oats-ws.sandbox.dunkindonuts.com|OATS WebSocket"
  "splunkelb.sandbox.dunkindonuts.com|Splunk ELB"
  "swagger.sandbox.dunkindonuts.com|Swagger Sandbox"
  "ecselb.sandbox.dunkindonuts.com|ECS ELB"
)

# === DNS RESOLUTION ===
echo "--- DNS Resolution ---" | tee -a "$OUTDIR/results.txt"
LIVE_TARGETS=()
for entry in "${TARGETS[@]}"; do
  domain=$(echo "$entry" | cut -d'|' -f1)
  label=$(echo "$entry" | cut -d'|' -f2)
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
  if [ -n "$cname" ] || [ -n "$a" ]; then
    echo "LIVE  $domain ($label) → CNAME: ${cname:-none} A: ${a:-none}" | tee -a "$OUTDIR/results.txt"
    LIVE_TARGETS+=("$entry")
  else
    echo "DEAD  $domain ($label)" | tee -a "$OUTDIR/results.txt"
  fi
done

# === DEEP PROBE LIVE TARGETS ===
for entry in "${LIVE_TARGETS[@]}"; do
  domain=$(echo "$entry" | cut -d'|' -f1)
  label=$(echo "$entry" | cut -d'|' -f2)
  safename=$(echo "$domain" | tr '.' '_')

  echo "" | tee -a "$OUTDIR/results.txt"
  echo "========================================" | tee -a "$OUTDIR/results.txt"
  echo "TARGET: $domain ($label)" | tee -a "$OUTDIR/results.txt"
  echo "========================================" | tee -a "$OUTDIR/results.txt"

  # HTTP method sweep
  echo "  Methods:" | tee -a "$OUTDIR/results.txt"
  for method in GET POST HEAD OPTIONS; do
    result=$(curl -sk --max-time 10 -X "$method" -o /dev/null -w '%{http_code} %{size_download}' "https://$domain/" 2>/dev/null)
    echo "    $method → $result" | tee -a "$OUTDIR/results.txt"
  done

  # Full headers
  echo "  Headers:" | tee -a "$OUTDIR/results.txt"
  curl -sk --max-time 10 -I "https://$domain/" 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "    FAILED" | tee -a "$OUTDIR/results.txt"

  # Capture body
  curl -sk --max-time 10 -D "$OUTDIR/${safename}.headers" "https://$domain/" > "$OUTDIR/${safename}.body" 2>/dev/null || true
  bodysize=$(wc -c < "$OUTDIR/${safename}.body" 2>/dev/null || echo 0)
  echo "  Body: ${bodysize} bytes" | tee -a "$OUTDIR/results.txt"
  if [ "$bodysize" -gt 0 ] && [ "$bodysize" -lt 5000 ]; then
    head -c 2000 "$OUTDIR/${safename}.body" 2>/dev/null | tee -a "$OUTDIR/results.txt"
    echo "" | tee -a "$OUTDIR/results.txt"
  fi

  # TLS cert
  echo "  TLS Cert:" | tee -a "$OUTDIR/results.txt"
  timeout 10 openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "    TLS FAILED" | tee -a "$OUTDIR/results.txt"

  # Path sweep (sandbox may be more open)
  echo "  Path sweep:" | tee -a "$OUTDIR/results.txt"
  for path in "/api" "/api/v1" "/health" "/status" "/swagger-ui" "/swagger-ui.html" "/v2/api-docs" "/v3/api-docs" "/docs" "/actuator" "/actuator/health" "/login" "/info"; do
    status=$(curl -sk --max-time 8 -o /dev/null -w '%{http_code}' "https://$domain$path" 2>/dev/null)
    if [ "$status" != "000" ]; then
      echo "    $path → $status" | tee -a "$OUTDIR/results.txt"
      if [ "$status" = "200" ]; then
        pathsafe=$(echo "$path" | tr '/.:-' '_')
        curl -sk --max-time 10 "https://$domain$path" > "$OUTDIR/${safename}${pathsafe}.body" 2>/dev/null || true
      fi
    fi
  done
done

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
echo "Completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
