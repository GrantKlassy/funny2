#!/bin/bash
# Swagger endpoint full probe: swagger.ddmdev.dunkindonuts.com on bare EC2
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/swagger-probe-2026-04-13:/out:Z \
#   investigator bash /work/scripts/18-swagger-probe.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"
TARGET="swagger.ddmdev.dunkindonuts.com"
IP="34.237.71.65"

echo "=== SWAGGER ENDPOINT FULL PROBE ===" | tee "$OUTDIR/results.txt"
echo "Target: $TARGET ($IP)" | tee -a "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# === DNS MULTI-RESOLVER ===
echo "--- DNS Resolution (multi-resolver) ---" | tee -a "$OUTDIR/results.txt"
for ns in 8.8.8.8 1.1.1.1 9.9.9.9 208.67.222.222; do
  a=$(dig +short "$TARGET" A @"$ns" 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$TARGET" CNAME @"$ns" 2>/dev/null | head -1)
  echo "  @$ns → A: ${a:-none}, CNAME: ${cname:-none}" | tee -a "$OUTDIR/results.txt"
done

# === REVERSE DNS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Reverse DNS ---" | tee -a "$OUTDIR/results.txt"
dig +short -x "$IP" @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

# === WHOIS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Whois ($IP) ---" | tee -a "$OUTDIR/results.txt"
whois "$IP" 2>/dev/null | grep -iE 'OrgName|OrgId|NetRange|CIDR|Country|City|StateProv|RegDate|Updated|Ref' | tee -a "$OUTDIR/results.txt"

# === TLS CERTIFICATE ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- TLS Certificate ---" | tee -a "$OUTDIR/results.txt"
timeout 10 openssl s_client -connect "$TARGET:443" -servername "$TARGET" </dev/null 2>/dev/null | openssl x509 -noout -text 2>/dev/null | grep -A1 'Subject:\|Issuer:\|Not Before\|Not After\|DNS:' | tee -a "$OUTDIR/results.txt" || echo "TLS FAILED" | tee -a "$OUTDIR/results.txt"

# Full cert SANs
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- TLS SANs (full) ---" | tee -a "$OUTDIR/results.txt"
timeout 10 openssl s_client -connect "$TARGET:443" -servername "$TARGET" </dev/null 2>/dev/null | openssl x509 -noout -ext subjectAltName 2>/dev/null | tr ',' '\n' | sed 's/^ *//' | tee -a "$OUTDIR/results.txt" || echo "SAN extraction FAILED" | tee -a "$OUTDIR/results.txt"

# === HTTP METHOD SWEEP on / ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- HTTP Method Sweep (/) ---" | tee -a "$OUTDIR/results.txt"
for method in GET POST HEAD OPTIONS PUT DELETE PATCH; do
  status=$(curl -sk --max-time 10 -X "$method" -o /dev/null -w '%{http_code}' "https://$TARGET/" 2>/dev/null)
  echo "  $method / → $status" | tee -a "$OUTDIR/results.txt"
done

# === SWAGGER PATH ENUMERATION ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Swagger/API Path Enumeration ---" | tee -a "$OUTDIR/results.txt"
PATHS=(
  "/"
  "/swagger-ui"
  "/swagger-ui/"
  "/swagger-ui.html"
  "/swagger-ui/index.html"
  "/v2/api-docs"
  "/v3/api-docs"
  "/openapi.json"
  "/openapi.yaml"
  "/api-docs"
  "/swagger-resources"
  "/swagger-resources/configuration/ui"
  "/v3/api-docs/swagger-config"
  "/actuator"
  "/actuator/health"
  "/actuator/info"
  "/actuator/env"
  "/health"
  "/status"
  "/info"
  "/version"
  "/api"
  "/api/v1"
  "/api/v2"
  "/docs"
  "/redoc"
  "/graphql"
  "/webjars/springfox-swagger-ui/springfox.css"
)

for path in "${PATHS[@]}"; do
  result=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code} %{size_download} %{content_type}' "https://$TARGET$path" 2>/dev/null)
  status=$(echo "$result" | awk '{print $1}')
  size=$(echo "$result" | awk '{print $2}')
  ctype=$(echo "$result" | awk '{print $3}')
  echo "  $path → $status (${size}B) [$ctype]" | tee -a "$OUTDIR/results.txt"

  # Capture full response for interesting status codes
  if [ "$status" = "200" ] || [ "$status" = "301" ] || [ "$status" = "302" ]; then
    safename=$(echo "$path" | tr '/' '_' | sed 's/^_//')
    [ -z "$safename" ] && safename="root"
    echo "  ** CAPTURING BODY → $safename.response **" | tee -a "$OUTDIR/results.txt"
    curl -sk --max-time 15 -D "$OUTDIR/${safename}.headers" "https://$TARGET$path" > "$OUTDIR/${safename}.body" 2>/dev/null || true
  fi
done

# === ALSO TRY HTTP (port 80) ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- HTTP (port 80) check ---" | tee -a "$OUTDIR/results.txt"
http_status=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' "http://$TARGET/" 2>/dev/null)
echo "  GET http://$TARGET/ → $http_status" | tee -a "$OUTDIR/results.txt"
if [ "$http_status" != "000" ]; then
  curl -s --max-time 10 -D "$OUTDIR/http-root.headers" "http://$TARGET/" > "$OUTDIR/http-root.body" 2>/dev/null || true
fi

# === NMAP TOP PORTS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Nmap Top 20 Ports ---" | tee -a "$OUTDIR/results.txt"
nmap -Pn --top-ports 20 -T4 "$IP" 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "nmap FAILED" | tee -a "$OUTDIR/results.txt"

# === BANNER GRAB ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Banner Grab ---" | tee -a "$OUTDIR/results.txt"
for port in 80 443 8080 8443 3000 5000 9090; do
  banner=$(echo "" | timeout 5 ncat -w 3 "$IP" "$port" 2>/dev/null | head -5 | tr '\n' ' ')
  if [ -n "$banner" ]; then
    echo "  Port $port: $banner" | tee -a "$OUTDIR/results.txt"
  else
    echo "  Port $port: no banner / closed" | tee -a "$OUTDIR/results.txt"
  fi
done

# === FULL HEADERS ON ROOT ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Full Response Headers (GET /) ---" | tee -a "$OUTDIR/results.txt"
curl -sk --max-time 10 -I "https://$TARGET/" 2>/dev/null | tee -a "$OUTDIR/results.txt" || echo "FAILED" | tee -a "$OUTDIR/results.txt"

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
echo "Completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
