#!/bin/bash
# Legacy/unknown service probing: star, fps, rbos, genesis, franchiseecentral, and more
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin:/work/investigations/dunkin:Z \
#   -v ./investigations/dunkin/artifacts/legacy-services-2026-04-13:/out:Z \
#   investigator bash /work/investigations/dunkin/scripts/12-legacy-services.sh
set -euo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== LEGACY / UNKNOWN SERVICE PROBING ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# Target list: known unknowns from GRAPH.md + CT log discoveries
TARGETS=(
  "star.dunkinbrands.com"
  "fps.dunkinbrands.com"
  "rbos.dunkinbrands.com"
  "genesisproduction.dunkinbrands.com"
  "genesissandbox.dunkinbrands.com"
  "franchiseecentral.dunkinbrands.com"
  "thecenter.dunkinbrands.com"
  "thecenteruat.dunkinbrands.com"
  "citrix.dunkinbrands.com"
  "sslvpn.dunkinbrands.com"
  "vdi.dunkinbrands.com"
  "smartsolve.dunkinbrands.com"
  "plmsupplier.dunkinbrands.com"
  "recognition.dunkinbrands.com"
  "poshc.dunkinbrands.com"
  "bam.dunkinbrands.com"
  "sts.dunkinbrands.com"
  "wsapi.dunkinbrands.com"
  "flq-prod-idp.dunkinbrands.com"
  "afm.dunkinbrands.com"
  "afm.dunkindonuts.com"
)

# === DNS RESOLUTION ===
echo "--- DNS Resolution ---" | tee -a "$OUTDIR/results.txt"
LIVE_TARGETS=()
for domain in "${TARGETS[@]}"; do
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
  aaaa=$(dig +short "$domain" AAAA @8.8.8.8 2>/dev/null | head -1)
  if [ -n "$cname" ]; then
    echo "LIVE  $domain → CNAME $cname → A: ${a:-unresolved}" | tee -a "$OUTDIR/results.txt"
    LIVE_TARGETS+=("$domain")
  elif [ -n "$a" ]; then
    echo "LIVE  $domain → A: $a" | tee -a "$OUTDIR/results.txt"
    LIVE_TARGETS+=("$domain")
  else
    echo "DEAD  $domain" | tee -a "$OUTDIR/results.txt"
  fi
done

# === HTTP METHOD SWEEP on live targets ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- HTTP Method Sweep (live targets) ---" | tee -a "$OUTDIR/results.txt"
for domain in "${LIVE_TARGETS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> $domain" | tee -a "$OUTDIR/results.txt"
  for method in GET POST HEAD OPTIONS PUT; do
    code=$(curl -s -o /dev/null -w '%{http_code}' -X "$method" --max-time 8 "https://$domain/" 2>/dev/null || echo "FAIL")
    echo "  $method / → $code" | tee -a "$OUTDIR/results.txt"
  done
done

# === DEEP PROBE: star.dunkinbrands.com (the 405 mystery) ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- DEEP PROBE: star.dunkinbrands.com ---" | tee -a "$OUTDIR/results.txt"
STAR_PATHS=("/" "/api" "/api/v1" "/api/v2" "/health" "/healthcheck" "/status" "/v1" "/v2" "/swagger-ui" "/swagger-ui.html" "/api-docs" "/star" "/Star" "/STAR")
for path in "${STAR_PATHS[@]}"; do
  for method in GET POST; do
    code=$(curl -s -o /dev/null -w '%{http_code}' -X "$method" --max-time 8 "https://star.dunkinbrands.com$path" 2>/dev/null || echo "FAIL")
    if [ "$code" != "000" ] && [ "$code" != "FAIL" ]; then
      echo "  $method $path → $code" | tee -a "$OUTDIR/results.txt"
    fi
  done
done

# Full headers on star
echo "" | tee -a "$OUTDIR/results.txt"
echo ">> star.dunkinbrands.com full headers (GET /):" | tee -a "$OUTDIR/results.txt"
curl -sI --max-time 8 "https://star.dunkinbrands.com/" 2>/dev/null | tee -a "$OUTDIR/results.txt"

echo ">> star.dunkinbrands.com full headers (POST /):" | tee -a "$OUTDIR/results.txt"
curl -sI -X POST --max-time 8 "https://star.dunkinbrands.com/" 2>/dev/null | tee -a "$OUTDIR/results.txt"

# Try with JSON content type
echo ">> star.dunkinbrands.com POST with JSON content-type:" | tee -a "$OUTDIR/results.txt"
curl -s --max-time 8 -X POST -H "Content-Type: application/json" -d '{}' "https://star.dunkinbrands.com/" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# === DEEP PROBE: fps.dunkinbrands.com (CAAS) ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- DEEP PROBE: fps.dunkinbrands.com (CAAS) ---" | tee -a "$OUTDIR/results.txt"

# DNS details
echo ">> DNS:" | tee -a "$OUTDIR/results.txt"
dig +short fps.dunkinbrands.com A @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
dig +short fps.dunkinbrands.com CNAME @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

# Get the ELB IP and reverse DNS
fps_ip=$(dig +short fps.dunkinbrands.com A @8.8.8.8 2>/dev/null | head -1)
if [ -n "$fps_ip" ]; then
  echo ">> Reverse DNS for $fps_ip:" | tee -a "$OUTDIR/results.txt"
  dig +short -x "$fps_ip" @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

  echo ">> Whois for $fps_ip:" | tee -a "$OUTDIR/results.txt"
  whois "$fps_ip" 2>/dev/null | grep -iE "^(orgname|org-name|netname|descr|cidr|netrange)" | tee -a "$OUTDIR/results.txt" || true
fi

# Port scan fps
echo ">> Port scan fps.dunkinbrands.com:" | tee -a "$OUTDIR/results.txt"
for port in 80 443 8080 8443 3000 5000 9090; do
  result=$(ncat -z -w 3 "fps.dunkinbrands.com" "$port" 2>&1 && echo "OPEN" || echo "CLOSED/FILTERED")
  echo "  :$port → $result" | tee -a "$OUTDIR/results.txt"
done

# TLS on fps
echo ">> TLS cert (if reachable):" | tee -a "$OUTDIR/results.txt"
{ echo | timeout 10 openssl s_client -connect "fps.dunkinbrands.com:443" -servername "fps.dunkinbrands.com" 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null || true; } | tee -a "$OUTDIR/results.txt"

# === DEEP PROBE: rbos.dunkinbrands.com ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- DEEP PROBE: rbos.dunkinbrands.com ---" | tee -a "$OUTDIR/results.txt"
echo ">> DNS:" | tee -a "$OUTDIR/results.txt"
dig +short rbos.dunkinbrands.com A @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
dig +short rbos.dunkinbrands.com CNAME @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

echo ">> HTTP probe:" | tee -a "$OUTDIR/results.txt"
curl -sI --max-time 10 "https://rbos.dunkinbrands.com/" 2>/dev/null | tee -a "$OUTDIR/results.txt"
echo ">> HTTP body (first 50 lines):" | tee -a "$OUTDIR/results.txt"
curl -sL --max-time 10 "https://rbos.dunkinbrands.com/" 2>/dev/null | head -50 | tee -a "$OUTDIR/results.txt"

# === DEEP PROBE: genesis ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- DEEP PROBE: Genesis Platform ---" | tee -a "$OUTDIR/results.txt"
for gdom in "genesisproduction.dunkinbrands.com" "genesissandbox.dunkinbrands.com"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> $gdom" | tee -a "$OUTDIR/results.txt"
  echo "DNS:" | tee -a "$OUTDIR/results.txt"
  dig +short "$gdom" A @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"
  dig +short "$gdom" CNAME @8.8.8.8 2>/dev/null | tee -a "$OUTDIR/results.txt"

  echo "HTTP headers:" | tee -a "$OUTDIR/results.txt"
  curl -sI --max-time 10 "https://$gdom/" 2>/dev/null | tee -a "$OUTDIR/results.txt"

  echo "HTTP body (first 30 lines):" | tee -a "$OUTDIR/results.txt"
  curl -sL --max-time 10 "https://$gdom/" 2>/dev/null | head -30 | tee -a "$OUTDIR/results.txt"
done

# === DEEP PROBE: franchiseecentral (the 2016 fossil) ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- DEEP PROBE: franchiseecentral.dunkinbrands.com ---" | tee -a "$OUTDIR/results.txt"

echo ">> Full headers:" | tee -a "$OUTDIR/results.txt"
curl -sI --max-time 10 "https://franchiseecentral.dunkinbrands.com/" 2>/dev/null | tee -a "$OUTDIR/results.txt"

echo ">> robots.txt:" | tee -a "$OUTDIR/results.txt"
curl -s --max-time 10 "https://franchiseecentral.dunkinbrands.com/robots.txt" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"

echo ">> sitemap.xml:" | tee -a "$OUTDIR/results.txt"
curl -s --max-time 10 "https://franchiseecentral.dunkinbrands.com/sitemap.xml" 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"

echo ">> Homepage body (first 50 lines):" | tee -a "$OUTDIR/results.txt"
curl -sL --max-time 10 "https://franchiseecentral.dunkinbrands.com/" 2>/dev/null | head -50 | tee -a "$OUTDIR/results.txt"

# Common paths
echo "" | tee -a "$OUTDIR/results.txt"
echo ">> Path sweep:" | tee -a "$OUTDIR/results.txt"
FC_PATHS=("/login" "/Login" "/admin" "/Admin" "/api" "/portal" "/Portal" "/Account" "/Default.aspx" "/home" "/Home")
for path in "${FC_PATHS[@]}"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "https://franchiseecentral.dunkinbrands.com$path" 2>/dev/null || echo "FAIL")
  echo "  $path → $code" | tee -a "$OUTDIR/results.txt"
done

# TLS cert
echo "" | tee -a "$OUTDIR/results.txt"
echo ">> TLS cert:" | tee -a "$OUTDIR/results.txt"
echo | timeout 10 openssl s_client -connect "franchiseecentral.dunkinbrands.com:443" -servername "franchiseecentral.dunkinbrands.com" 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | head -20 | tee -a "$OUTDIR/results.txt"

# === TLS CERTS for all live legacy targets ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- TLS Certs (remaining live targets) ---" | tee -a "$OUTDIR/results.txt"
for domain in "${LIVE_TARGETS[@]}"; do
  # Skip the ones we already did detailed probes on
  [[ "$domain" == "star.dunkinbrands.com" ]] && continue
  [[ "$domain" == "fps.dunkinbrands.com" ]] && continue
  [[ "$domain" == "franchiseecentral.dunkinbrands.com" ]] && continue
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> $domain" | tee -a "$OUTDIR/results.txt"
  { echo | timeout 10 openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null || true; } | tee -a "$OUTDIR/results.txt"
done

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
