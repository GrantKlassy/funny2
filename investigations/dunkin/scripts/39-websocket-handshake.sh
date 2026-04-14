#!/bin/bash
# WebSocket handshake attempt on POS endpoints
# pos-ws and dbapi-ws returned 426 Upgrade Required — try actual WebSocket upgrade
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/websocket-handshake-2026-04-13:/out:Z \
#   investigator bash /work/scripts/39-websocket-handshake.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== WEBSOCKET POS HANDSHAKE PROBE ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

WS_TARGETS=(
  "pos-ws.dunkindonuts.com"
  "dbapi-ws.dunkindonuts.com"
)

for domain in "${WS_TARGETS[@]}"; do
  echo "========================================" | tee -a "$OUTDIR/results.txt"
  echo "TARGET: $domain" | tee -a "$OUTDIR/results.txt"
  echo "========================================" | tee -a "$OUTDIR/results.txt"

  # DNS
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
  echo "A: ${a:-NXDOMAIN}  CNAME: ${cname:-none}" | tee -a "$OUTDIR/results.txt"

  if [ -z "$a" ] && [ -z "$cname" ]; then
    echo "SKIP — no DNS" | tee -a "$OUTDIR/results.txt"
    continue
  fi

  # Confirm 426 status
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "--- Confirm 426 ---" | tee -a "$OUTDIR/results.txt"
  curl -sk --max-time 10 -D "$OUTDIR/${domain}-get-headers.txt" -o "$OUTDIR/${domain}-get-body.txt" "https://$domain/" 2>/dev/null
  status=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' "https://$domain/" 2>/dev/null)
  echo "GET / → $status" | tee -a "$OUTDIR/results.txt"
  cat "$OUTDIR/${domain}-get-headers.txt" 2>/dev/null | tee -a "$OUTDIR/results.txt"
  cat "$OUTDIR/${domain}-get-body.txt" 2>/dev/null | head -5 | tee -a "$OUTDIR/results.txt"

  # TLS cert
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "--- TLS Certificate ---" | tee -a "$OUTDIR/results.txt"
  echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | tee -a "$OUTDIR/results.txt"

  # WebSocket upgrade attempt (via curl)
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "--- WebSocket Upgrade (curl) ---" | tee -a "$OUTDIR/results.txt"
  curl -sk --max-time 10 \
    -H "Upgrade: websocket" \
    -H "Connection: Upgrade" \
    -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    -H "Sec-WebSocket-Version: 13" \
    -D "$OUTDIR/${domain}-ws-headers.txt" \
    -o "$OUTDIR/${domain}-ws-body.txt" \
    "https://$domain/" 2>/dev/null
  ws_status=$(head -1 "$OUTDIR/${domain}-ws-headers.txt" 2>/dev/null)
  echo "WebSocket upgrade response: $ws_status" | tee -a "$OUTDIR/results.txt"
  cat "$OUTDIR/${domain}-ws-headers.txt" 2>/dev/null | tee -a "$OUTDIR/results.txt"

  # Try with Origin header
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "--- WebSocket with Origin ---" | tee -a "$OUTDIR/results.txt"
  curl -sk --max-time 10 \
    -H "Upgrade: websocket" \
    -H "Connection: Upgrade" \
    -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Origin: https://www.dunkindonuts.com" \
    -D "$OUTDIR/${domain}-ws-origin-headers.txt" \
    -o "$OUTDIR/${domain}-ws-origin-body.txt" \
    "https://$domain/" 2>/dev/null
  origin_status=$(head -1 "$OUTDIR/${domain}-ws-origin-headers.txt" 2>/dev/null)
  echo "With Origin: $origin_status" | tee -a "$OUTDIR/results.txt"

  # Try subprotocols
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "--- WebSocket Subprotocol Probe ---" | tee -a "$OUTDIR/results.txt"
  for proto in "graphql-ws" "graphql-transport-ws" "mqtt" "stomp" "wamp.2.json" "soap" "v10.stomp" "v11.stomp"; do
    sp_status=$(curl -sk --max-time 8 \
      -H "Upgrade: websocket" \
      -H "Connection: Upgrade" \
      -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
      -H "Sec-WebSocket-Version: 13" \
      -H "Sec-WebSocket-Protocol: $proto" \
      -o /dev/null -w '%{http_code}' \
      "https://$domain/" 2>/dev/null)
    echo "  Protocol: $proto → $sp_status" | tee -a "$OUTDIR/results.txt"
  done

  # Try raw WebSocket via openssl s_client + ncat
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "--- Raw WebSocket via openssl ---" | tee -a "$OUTDIR/results.txt"
  WS_REQUEST="GET / HTTP/1.1\r\nHost: ${domain}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\nOrigin: https://www.dunkindonuts.com\r\n\r\n"
  echo -e "$WS_REQUEST" | timeout 10 openssl s_client -connect "${domain}:443" -servername "$domain" -quiet 2>/dev/null | head -30 | tee -a "$OUTDIR/results.txt"

  # Path variants
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "--- Path Variants ---" | tee -a "$OUTDIR/results.txt"
  for path in "/" "/ws" "/websocket" "/socket" "/connect" "/pos" "/api" "/v1" "/v2"; do
    p_status=$(curl -sk --max-time 8 \
      -H "Upgrade: websocket" \
      -H "Connection: Upgrade" \
      -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
      -H "Sec-WebSocket-Version: 13" \
      -o /dev/null -w '%{http_code}' \
      "https://$domain$path" 2>/dev/null)
    echo "  $path → $p_status" | tee -a "$OUTDIR/results.txt"
  done

  echo "" | tee -a "$OUTDIR/results.txt"
done

echo "=== PROBE COMPLETE ===" | tee -a "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
