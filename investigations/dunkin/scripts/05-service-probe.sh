#!/usr/bin/env bash
# 05-service-probe.sh — vendor fingerprinting, Reddit API, iTunes lookup
set -euo pipefail

echo "=== Landing page vendor fingerprint ==="
curl -s -H "User-Agent: Mozilla/5.0 (iPhone)" \
  "https://ulink.prod.ddmprod.dunkindonuts.com/dunkin/orders/category/119" | \
  grep -ioE "branch|adjust|appsflyer|kochava|firebase|singular|smart\.link|segment|gtm|analytics" || echo "no vendor refs in HTML"

echo -e "\n=== Branch.io smart link check ==="
curl -sv "https://dunkin.smart.link/f6iexb4x5" 2>&1 | head -40

echo -e "\n=== Reddit u/dunkin profile ==="
curl -s "https://www.reddit.com/user/dunkin/about.json" \
  -H "User-Agent: funny2-osint/1.0" | \
  jq ".data | {name, id, created_utc, link_karma, comment_karma, verified, has_verified_email, is_mod}" 2>/dev/null

echo -e "\n=== iTunes app lookup ==="
curl -s "https://itunes.apple.com/search?term=dunkin&entity=software&country=US&limit=3" | \
  jq ".results[] | {trackName, bundleId, sellerName}" 2>/dev/null
