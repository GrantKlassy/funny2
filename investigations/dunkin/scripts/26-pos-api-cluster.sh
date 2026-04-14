#!/bin/bash
# POS/DBAPI/OPC endpoint cluster from CT logs — never HTTP-probed
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/pos-api-cluster-2026-04-13:/out:Z \
#   investigator bash /work/scripts/26-pos-api-cluster.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== POS / DBAPI / OPC ENDPOINT CLUSTER ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

TARGETS=(
  "pos-api.dunkindonuts.com|Point of Sale API"
  "pos-ws.dunkindonuts.com|POS WebSocket"
  "opc-api.dunkindonuts.com|OPC API"
  "dbapi.dunkindonuts.com|Database API"
  "dbapi-ws.dunkindonuts.com|Database API WebSocket"
  "ddapi.dunkindonuts.com|DD API"
  "ddapi.staging.dunkindonuts.com|DD API Staging"
  "ddwlapi.staging.dunkindonuts.com|DD White Label API Staging"
)

for entry in "${TARGETS[@]}"; do
  domain=$(echo "$entry" | cut -d'|' -f1)
  label=$(echo "$entry" | cut -d'|' -f2)
  safename=$(echo "$domain" | tr '.' '_')

  echo "========================================" | tee -a "$OUTDIR/results.txt"
  echo "TARGET: $domain ($label)" | tee -a "$OUTDIR/results.txt"
  echo "========================================" | tee -a "$OUTDIR/results.txt"

  # DNS
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
  echo "  DNS → CNAME: ${cname:-none} A: ${a:-none}" | tee -a "$OUTDIR/results.txt"

  if [ -z "$a" ] && [ -z "$cname" ]; then
    echo "  DEAD" | tee -a "$OUTDIR/results.txt"
    echo "" | tee -a "$OUTDIR/results.txt"
    continue
  fi

  # HTTP method sweep
  echo "  Method sweep:" | tee -a "$OUTDIR/results.txt"
  for method in GET POST HEAD OPTIONS; do
    result=$(curl -sk --max-time 10 -X "$method" -o /dev/null -w '%{http_code} %{size_download}' "https://$domain/" 2>/dev/null)
    echo "    $method → $result" | tee -a "$OUTDIR/results.txt"
  done

  # Full headers
  echo "  Headers:" | tee -a "$OUTDIR/results.txt"
  curl -sk --max-time 10 -I "https://$domain/" 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "    FAILED" | tee -a "$OUTDIR/results.txt"

  # Check for API Gateway headers
  echo "  API Gateway detection:" | tee -a "$OUTDIR/results.txt"
  headers=$(curl -sk --max-time 10 -I "https://$domain/" 2>/dev/null)
  for hdr in "x-amzn-requestid" "x-amz-apigw-id" "x-amz-cf-id" "x-amzn-errortype"; do
    val=$(echo "$headers" | grep -i "^$hdr:" | head -1 | tr -d '\r')
    if [ -n "$val" ]; then
      echo "    $val" | tee -a "$OUTDIR/results.txt"
    fi
  done

  # Capture body
  curl -sk --max-time 10 -D "$OUTDIR/${safename}.headers" "https://$domain/" > "$OUTDIR/${safename}.body" 2>/dev/null || true
  bodysize=$(wc -c < "$OUTDIR/${safename}.body" 2>/dev/null || echo 0)
  echo "  Body: ${bodysize} bytes" | tee -a "$OUTDIR/results.txt"
  if [ "$bodysize" -gt 0 ] && [ "$bodysize" -lt 5000 ]; then
    echo "  Body preview:" | tee -a "$OUTDIR/results.txt"
    head -c 2000 "$OUTDIR/${safename}.body" 2>/dev/null | tee -a "$OUTDIR/results.txt"
    echo "" | tee -a "$OUTDIR/results.txt"
  fi

  # TLS cert
  echo "  TLS Cert:" | tee -a "$OUTDIR/results.txt"
  timeout 10 openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "    TLS FAILED" | tee -a "$OUTDIR/results.txt"

  # Path sweep for API endpoints
  echo "  Path sweep:" | tee -a "$OUTDIR/results.txt"
  for path in "/api" "/api/v1" "/health" "/status" "/swagger-ui" "/v2/api-docs" "/docs"; do
    status=$(curl -sk --max-time 8 -o /dev/null -w '%{http_code}' "https://$domain$path" 2>/dev/null)
    if [ "$status" != "000" ] && [ "$status" != "403" ]; then
      echo "    $path → $status" | tee -a "$OUTDIR/results.txt"
    fi
  done

  echo "" | tee -a "$OUTDIR/results.txt"
done

echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
echo "Completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
