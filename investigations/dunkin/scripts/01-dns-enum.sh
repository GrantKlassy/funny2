#!/usr/bin/env bash
# 01-dns-enum.sh — DNS enumeration for dunkindonuts.com / ddmprod zone
# Usage: podman run --rm --dns 8.8.8.8 -v ./investigations/dunkin:/work/investigations/dunkin:Z investigator bash /work/investigations/dunkin/scripts/01-dns-enum.sh
# Or run inline: podman run --rm --dns 8.8.8.8 investigator bash -c "$(cat investigations/dunkin/scripts/01-dns-enum.sh)"
set -euo pipefail

echo "=== Root domain records ==="
for TYPE in A AAAA MX NS TXT SOA CAA; do
  echo "--- $TYPE ---"
  dig +noall +answer dunkindonuts.com "$TYPE" 2>/dev/null || true
done

echo -e "\n=== Subdomain probe ==="
for SUB in ulink.prod.ddmprod k.prod.ddmprod prod.ddmprod ddmprod \
           staging.ddmprod dev.ddmprod api.prod.ddmprod app.prod.ddmprod \
           www m mobileapi order orders app \
           ulink.staging.ddmprod k.staging.ddmprod; do
  FQDN="$SUB.dunkindonuts.com"
  A=$(dig +short "$FQDN" A 2>/dev/null)
  CNAME=$(dig +short "$FQDN" CNAME 2>/dev/null)
  if [ -n "$A" ] || [ -n "$CNAME" ]; then
    echo "HIT $FQDN -> A:${A:-none} CNAME:${CNAME:-none}"
  else
    echo "MISS $FQDN"
  fi
done

echo -e "\n=== DMARC ==="
dig +noall +answer _dmarc.dunkindonuts.com TXT 2>/dev/null

echo -e "\n=== DKIM selector sweep ==="
for SEL in google s1 s2 k1 k2 selector1 selector2 \
           em braze sailthru mailchimp sendgrid mandrill sparkpost default; do
  RESULT=$(dig +short "${SEL}._domainkey.dunkindonuts.com" TXT 2>/dev/null)
  [ -n "$RESULT" ] && echo "DKIM HIT: $SEL -> $RESULT"
done

echo -e "\n=== Multi-resolver check ==="
for RESOLVER in 8.8.8.8 1.1.1.1 9.9.9.9; do
  echo "--- @$RESOLVER ---"
  dig +short @"$RESOLVER" ulink.prod.ddmprod.dunkindonuts.com A CNAME 2>/dev/null || true
done
