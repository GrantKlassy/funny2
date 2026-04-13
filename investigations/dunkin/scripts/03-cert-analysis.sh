#!/usr/bin/env bash
# 03-cert-analysis.sh — TLS certificate inspection and CT log search
set -euo pipefail

for HOST in ulink.prod.ddmprod.dunkindonuts.com \
            k.prod.ddmprod.dunkindonuts.com \
            dunkindonuts.com \
            www.dunkindonuts.com; do
  echo "=== CERT: $HOST ==="
  echo | openssl s_client -connect "$HOST:443" -servername "$HOST" 2>/dev/null | \
    openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null || echo "FAILED"
  echo ""
done

echo "=== Full cert chain: ulink.prod.ddmprod ==="
echo | openssl s_client -connect ulink.prod.ddmprod.dunkindonuts.com:443 \
  -servername ulink.prod.ddmprod.dunkindonuts.com -showcerts 2>/dev/null | head -80

echo -e "\n=== crt.sh: ddmprod.dunkindonuts.com ==="
curl -s "https://crt.sh/?q=%25.ddmprod.dunkindonuts.com&output=json" | \
  jq -r ".[].name_value" 2>/dev/null | sort -u || echo "query failed"

echo -e "\n=== crt.sh: ddmprod on any domain ==="
curl -s "https://crt.sh/?q=ddmprod&output=json" | \
  jq -r ".[].name_value" 2>/dev/null | sort -u | head -50 || echo "query failed"
