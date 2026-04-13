#!/usr/bin/env bash
# 06-osint.sh — Wayback Machine, whois
set -euo pipefail

echo "=== Whois ==="
whois dunkindonuts.com 2>/dev/null | head -30

echo -e "\n=== Wayback: ddmprod.dunkindonuts.com ==="
curl -s "https://web.archive.org/cdx/search/cdx?url=*.ddmprod.dunkindonuts.com&output=json&fl=timestamp,original,statuscode&collapse=urlkey&limit=50" | \
  jq . 2>/dev/null || echo "wayback query failed"
