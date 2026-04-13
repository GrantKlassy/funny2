#!/usr/bin/env bash
# 04-port-scan.sh — nmap top-20 port scan
set -euo pipefail

echo "=== nmap: ulink.prod.ddmprod ==="
nmap -Pn -sT --top-ports 20 -T3 ulink.prod.ddmprod.dunkindonuts.com 2>&1

echo -e "\n=== Banner grab ==="
for PORT in 80 443 8080 8443; do
  echo "--- Port $PORT ---"
  echo | ncat -w 3 ulink.prod.ddmprod.dunkindonuts.com "$PORT" 2>&1 | head -5 || true
done
