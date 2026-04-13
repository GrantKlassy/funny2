#!/usr/bin/env bash
# 02-http-probe.sh — HTTP redirect chains, AASA, UA variations, category sweep
set -euo pipefail
TARGET="https://ulink.prod.ddmprod.dunkindonuts.com/dunkin/orders/category/119"

echo "=== Redirect chain (iPhone) ==="
curl -sv -L -D- -o /dev/null \
  -H "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15" \
  "$TARGET" 2>&1 | head -80

echo -e "\n=== Redirect chain (Desktop) ==="
curl -sv -L -D- -o /dev/null \
  -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) Chrome/124.0.0.0" \
  "$TARGET" 2>&1 | head -80

echo -e "\n=== Redirect chain (Redditbot) ==="
curl -sv -D- -o /dev/null -H "User-Agent: Redditbot/1.0" "$TARGET" 2>&1 | head -40

echo -e "\n=== AASA ==="
curl -s "https://ulink.prod.ddmprod.dunkindonuts.com/.well-known/apple-app-site-association" | jq . 2>/dev/null

echo -e "\n=== Android Asset Links ==="
curl -s "https://ulink.prod.ddmprod.dunkindonuts.com/.well-known/assetlinks.json" 2>/dev/null

echo -e "\n=== Landing page HTML (iPhone) ==="
curl -s -H "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)" "$TARGET"

echo -e "\n=== Category sweep ==="
for CAT in $(seq 100 130); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 \
    "https://ulink.prod.ddmprod.dunkindonuts.com/dunkin/orders/category/$CAT")
  echo "category/$CAT -> $CODE"
done

echo -e "\n=== Cookie dump ==="
curl -sv -c- -L -o /dev/null \
  -H "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)" \
  "$TARGET" 2>&1 | grep -i "set-cookie"
