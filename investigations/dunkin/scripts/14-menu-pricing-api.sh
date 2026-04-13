#!/bin/bash
# Menu pricing API deep dive: Spring Boot actuator, Swagger, API discovery
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin:/work/investigations/dunkin:Z \
#   -v ./investigations/dunkin/artifacts/menu-pricing-api-2026-04-13:/out:Z \
#   investigator bash /work/investigations/dunkin/scripts/14-menu-pricing-api.sh
set -euo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== MENU PRICING API DEEP DIVE ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

HOSTS=("menu-pricing-prd.dunkindonuts.com" "menu-pricing-stg.dunkindonuts.com" "menu-pricing-prd1.dunkindonuts.com")

# === DNS RESOLUTION ===
echo "--- DNS Resolution ---" | tee -a "$OUTDIR/results.txt"
for host in "${HOSTS[@]}"; do
  a=$(dig +short "$host" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$host" CNAME @8.8.8.8 2>/dev/null | head -1)
  echo "$host → CNAME: ${cname:-none} A: ${a:-unresolved}" | tee -a "$OUTDIR/results.txt"
done

# === BASELINE HEADERS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Baseline Headers (GET /) ---" | tee -a "$OUTDIR/results.txt"
for host in "${HOSTS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> $host" | tee -a "$OUTDIR/results.txt"
  curl -sI --max-time 10 "https://$host/" 2>/dev/null | tee -a "$OUTDIR/results.txt"
done

# === SPRING BOOT ACTUATOR SWEEP ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Spring Boot Actuator Sweep ---" | tee -a "$OUTDIR/results.txt"

ACTUATOR_PATHS=(
  "/actuator"
  "/actuator/health"
  "/actuator/health/liveness"
  "/actuator/health/readiness"
  "/actuator/info"
  "/actuator/env"
  "/actuator/beans"
  "/actuator/configprops"
  "/actuator/mappings"
  "/actuator/metrics"
  "/actuator/loggers"
  "/actuator/conditions"
  "/actuator/scheduledtasks"
  "/actuator/caches"
  "/actuator/flyway"
  "/actuator/liquibase"
  "/manage"
  "/manage/health"
  "/manage/info"
  "/admin"
  "/admin/health"
)

for host in "${HOSTS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> Actuator sweep: $host" | tee -a "$OUTDIR/results.txt"
  for path in "${ACTUATOR_PATHS[@]}"; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "https://$host$path" 2>/dev/null || echo "FAIL")
    if [ "$code" != "000" ] && [ "$code" != "FAIL" ]; then
      echo "  $path → $code" | tee -a "$OUTDIR/results.txt"
      # If 200, capture the body
      if [ "$code" = "200" ]; then
        echo "  [BODY]:" | tee -a "$OUTDIR/results.txt"
        curl -s --max-time 8 "https://$host$path" 2>/dev/null | jq . 2>/dev/null | head -50 | tee -a "$OUTDIR/results.txt"
        echo "  [/BODY]" | tee -a "$OUTDIR/results.txt"
      fi
    fi
  done
done

# === API DISCOVERY / SWAGGER ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- API Discovery / Swagger ---" | tee -a "$OUTDIR/results.txt"

API_PATHS=(
  "/swagger-ui"
  "/swagger-ui.html"
  "/swagger-ui/index.html"
  "/swagger-resources"
  "/v2/api-docs"
  "/v3/api-docs"
  "/v3/api-docs/swagger-config"
  "/api"
  "/api/v1"
  "/api/v2"
  "/api/menu"
  "/api/pricing"
  "/api/stores"
  "/api/categories"
  "/api/products"
  "/menu"
  "/pricing"
  "/stores"
  "/categories"
  "/products"
  "/graphql"
  "/graphiql"
)

for host in "${HOSTS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> API discovery: $host" | tee -a "$OUTDIR/results.txt"
  for path in "${API_PATHS[@]}"; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "https://$host$path" 2>/dev/null || echo "FAIL")
    if [ "$code" != "000" ] && [ "$code" != "FAIL" ]; then
      echo "  $path → $code" | tee -a "$OUTDIR/results.txt"
      if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ]; then
        echo "  [BODY/REDIRECT]:" | tee -a "$OUTDIR/results.txt"
        curl -sI --max-time 8 "https://$host$path" 2>/dev/null | grep -iE "^(HTTP|location|content-type)" | tee -a "$OUTDIR/results.txt" || true
        curl -s --max-time 8 "https://$host$path" 2>/dev/null | head -30 | tee -a "$OUTDIR/results.txt"
        echo "  [/BODY]" | tee -a "$OUTDIR/results.txt"
      fi
    fi
  done
done

# === CONTENT-TYPE PROBING ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Content-Type Probing ---" | tee -a "$OUTDIR/results.txt"

for host in "${HOSTS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> $host" | tee -a "$OUTDIR/results.txt"

  # GET with Accept: application/json
  echo "  GET / Accept: application/json" | tee -a "$OUTDIR/results.txt"
  curl -s --max-time 8 -H "Accept: application/json" "https://$host/" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"

  # GET with Accept: application/xml
  echo "  GET / Accept: application/xml" | tee -a "$OUTDIR/results.txt"
  curl -s --max-time 8 -H "Accept: application/xml" "https://$host/" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"

  # POST with empty JSON body
  echo "  POST / Content-Type: application/json (empty body)" | tee -a "$OUTDIR/results.txt"
  curl -s --max-time 8 -X POST -H "Content-Type: application/json" -d '{}' "https://$host/" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"

  # POST to common API paths
  echo "  POST /api Content-Type: application/json" | tee -a "$OUTDIR/results.txt"
  curl -s --max-time 8 -X POST -H "Content-Type: application/json" -d '{}' "https://$host/api" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"
done

# === TLS CERT COMPARISON ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- TLS Certificates ---" | tee -a "$OUTDIR/results.txt"
for host in "${HOSTS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> $host" | tee -a "$OUTDIR/results.txt"
  echo | timeout 10 openssl s_client -connect "$host:443" -servername "$host" 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | head -25 | tee -a "$OUTDIR/results.txt" || echo "  TLS failed" | tee -a "$OUTDIR/results.txt"
done

# === ERROR MESSAGE ANALYSIS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Error Message Analysis ---" | tee -a "$OUTDIR/results.txt"
for host in "${HOSTS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> $host 404 response body:" | tee -a "$OUTDIR/results.txt"
  curl -s --max-time 8 "https://$host/nonexistent-probe-test" 2>/dev/null | head -30 | tee -a "$OUTDIR/results.txt"
done

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
