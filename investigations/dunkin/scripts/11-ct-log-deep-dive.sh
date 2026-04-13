#!/bin/bash
# CT log deep dive: full enumeration of dunkinbrands.com + dunkindonuts.com + ddmprod certs
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin:/work/investigations/dunkin:Z \
#   -v ./investigations/dunkin/artifacts/ct-log-deep-dive-2026-04-13:/out:Z \
#   investigator bash /work/investigations/dunkin/scripts/11-ct-log-deep-dive.sh
set -euo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== CT LOG DEEP DIVE ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# === DUNKINBRANDS.COM CT LOGS ===
echo "--- crt.sh: %.dunkinbrands.com ---" | tee -a "$OUTDIR/results.txt"
crt_brands=$(curl -s --max-time 90 --retry 2 "https://crt.sh/?q=%25.dunkinbrands.com&output=json" 2>/dev/null || echo "TIMEOUT")
if [ "$crt_brands" != "TIMEOUT" ] && echo "$crt_brands" | jq . >/dev/null 2>&1; then
  echo "$crt_brands" > "$OUTDIR/crt-dunkinbrands-raw.json"
  total=$(echo "$crt_brands" | jq length)
  echo "Total cert entries: $total" | tee -a "$OUTDIR/results.txt"

  # Extract unique subdomains
  echo "$crt_brands" | jq -r '.[].name_value' 2>/dev/null | tr '\n' '\n' | sed 's/\*\.//g' | sort -u > "$OUTDIR/subdomains-dunkinbrands.txt"
  sub_count=$(wc -l < "$OUTDIR/subdomains-dunkinbrands.txt")
  echo "Unique subdomains: $sub_count" | tee -a "$OUTDIR/results.txt"
  echo "" | tee -a "$OUTDIR/results.txt"

  # Full subdomain list
  echo ">> All unique dunkinbrands.com subdomains:" | tee -a "$OUTDIR/results.txt"
  cat "$OUTDIR/subdomains-dunkinbrands.txt" | tee -a "$OUTDIR/results.txt"
  echo "" | tee -a "$OUTDIR/results.txt"

  # Categorize
  echo ">> Categorization:" | tee -a "$OUTDIR/results.txt"
  echo "  Remote Access:" | tee -a "$OUTDIR/results.txt"
  grep -iE "citrix|vpn|vdi|xen|remote|netscaler|ica" "$OUTDIR/subdomains-dunkinbrands.txt" | sed 's/^/    /' | tee -a "$OUTDIR/results.txt" || echo "    (none)" | tee -a "$OUTDIR/results.txt"

  echo "  Collaboration:" | tee -a "$OUTDIR/results.txt"
  grep -iE "quickplace|quickr|inotes|collab|notes|sametime|connections" "$OUTDIR/subdomains-dunkinbrands.txt" | sed 's/^/    /' | tee -a "$OUTDIR/results.txt" || echo "    (none)" | tee -a "$OUTDIR/results.txt"

  echo "  Identity/SSO:" | tee -a "$OUTDIR/results.txt"
  grep -iE "sso|idp|sts|auth|identity|saml|adfs|login|oauth" "$OUTDIR/subdomains-dunkinbrands.txt" | sed 's/^/    /' | tee -a "$OUTDIR/results.txt" || echo "    (none)" | tee -a "$OUTDIR/results.txt"

  echo "  Mobile/MDM:" | tee -a "$OUTDIR/results.txt"
  grep -iE "smartphone|mdm|mobile|airwatch|maas360" "$OUTDIR/subdomains-dunkinbrands.txt" | sed 's/^/    /' | tee -a "$OUTDIR/results.txt" || echo "    (none)" | tee -a "$OUTDIR/results.txt"

  echo "  Development/QA:" | tee -a "$OUTDIR/results.txt"
  grep -iE "dev|qa|uat|staging|test|sandbox|preprod" "$OUTDIR/subdomains-dunkinbrands.txt" | sed 's/^/    /' | tee -a "$OUTDIR/results.txt" || echo "    (none)" | tee -a "$OUTDIR/results.txt"

  echo "  Supply Chain/Quality:" | tee -a "$OUTDIR/results.txt"
  grep -iE "plm|supplier|supply|smartsolve|quality|vendor" "$OUTDIR/subdomains-dunkinbrands.txt" | sed 's/^/    /' | tee -a "$OUTDIR/results.txt" || echo "    (none)" | tee -a "$OUTDIR/results.txt"

  echo "  Internal Apps:" | tee -a "$OUTDIR/results.txt"
  grep -iE "genesis|rbos|poshc|thecenter|star|fps|bam|recognition|afm|wsapi|flq" "$OUTDIR/subdomains-dunkinbrands.txt" | sed 's/^/    /' | tee -a "$OUTDIR/results.txt" || echo "    (none)" | tee -a "$OUTDIR/results.txt"

  echo "  Infrastructure:" | tee -a "$OUTDIR/results.txt"
  grep -iE "dns|ns[0-9]|mail|smtp|mx|relay|ftp|ntp|proxy|lb|waf|cdn" "$OUTDIR/subdomains-dunkinbrands.txt" | sed 's/^/    /' | tee -a "$OUTDIR/results.txt" || echo "    (none)" | tee -a "$OUTDIR/results.txt"

  echo "  Franchising:" | tee -a "$OUTDIR/results.txt"
  grep -iE "franchise|franchis" "$OUTDIR/subdomains-dunkinbrands.txt" | sed 's/^/    /' | tee -a "$OUTDIR/results.txt" || echo "    (none)" | tee -a "$OUTDIR/results.txt"

  echo "  QR/Menu:" | tee -a "$OUTDIR/results.txt"
  grep -iE "qr|menu|kiosk" "$OUTDIR/subdomains-dunkinbrands.txt" | sed 's/^/    /' | tee -a "$OUTDIR/results.txt" || echo "    (none)" | tee -a "$OUTDIR/results.txt"

  # Email address extraction from cert CNs/SANs
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> Email addresses in certs:" | tee -a "$OUTDIR/results.txt"
  echo "$crt_brands" | jq -r '.[].name_value' 2>/dev/null | grep '@' | sort -u | tee -a "$OUTDIR/results.txt" || echo "  (none found)" | tee -a "$OUTDIR/results.txt"

  # Common names (CN) — may differ from SANs
  echo "" | tee -a "$OUTDIR/results.txt"
  echo ">> Unique Common Names (CN) from certs:" | tee -a "$OUTDIR/results.txt"
  echo "$crt_brands" | jq -r '.[].common_name' 2>/dev/null | sort -u | tee -a "$OUTDIR/results.txt"
else
  echo "  crt.sh query FAILED or timed out" | tee -a "$OUTDIR/results.txt"
fi

# === DUNKINDONUTS.COM CT LOGS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- crt.sh: %.dunkindonuts.com ---" | tee -a "$OUTDIR/results.txt"
crt_donuts=$(curl -s --max-time 90 --retry 2 "https://crt.sh/?q=%25.dunkindonuts.com&output=json" 2>/dev/null || echo "TIMEOUT")
if [ "$crt_donuts" != "TIMEOUT" ] && echo "$crt_donuts" | jq . >/dev/null 2>&1; then
  echo "$crt_donuts" > "$OUTDIR/crt-dunkindonuts-raw.json"
  total=$(echo "$crt_donuts" | jq length)
  echo "Total cert entries: $total" | tee -a "$OUTDIR/results.txt"

  echo "$crt_donuts" | jq -r '.[].name_value' 2>/dev/null | tr '\n' '\n' | sed 's/\*\.//g' | sort -u > "$OUTDIR/subdomains-dunkindonuts.txt"
  sub_count=$(wc -l < "$OUTDIR/subdomains-dunkindonuts.txt")
  echo "Unique subdomains: $sub_count" | tee -a "$OUTDIR/results.txt"
  echo "" | tee -a "$OUTDIR/results.txt"

  echo ">> All unique dunkindonuts.com subdomains:" | tee -a "$OUTDIR/results.txt"
  cat "$OUTDIR/subdomains-dunkindonuts.txt" | tee -a "$OUTDIR/results.txt"
  echo "" | tee -a "$OUTDIR/results.txt"

  # Unique CNs
  echo ">> Unique Common Names (CN):" | tee -a "$OUTDIR/results.txt"
  echo "$crt_donuts" | jq -r '.[].common_name' 2>/dev/null | sort -u | tee -a "$OUTDIR/results.txt"
else
  echo "  crt.sh query FAILED or timed out" | tee -a "$OUTDIR/results.txt"
fi

# === DDMPROD CT LOGS (retry) ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- crt.sh: %.ddmprod.dunkindonuts.com (RETRY) ---" | tee -a "$OUTDIR/results.txt"
crt_ddmprod=$(curl -s --max-time 90 --retry 2 "https://crt.sh/?q=%25.ddmprod.dunkindonuts.com&output=json" 2>/dev/null || echo "TIMEOUT")
if [ "$crt_ddmprod" != "TIMEOUT" ] && echo "$crt_ddmprod" | jq . >/dev/null 2>&1; then
  echo "$crt_ddmprod" > "$OUTDIR/crt-ddmprod-raw.json"
  total=$(echo "$crt_ddmprod" | jq length)
  echo "Total cert entries: $total" | tee -a "$OUTDIR/results.txt"

  echo "$crt_ddmprod" | jq -r '.[].name_value' 2>/dev/null | tr '\n' '\n' | sed 's/\*\.//g' | sort -u | tee -a "$OUTDIR/results.txt"
else
  echo "  crt.sh query FAILED or timed out" | tee -a "$OUTDIR/results.txt"
fi

# === RESOLUTION CHECK — which dunkinbrands.com subdomains still resolve? ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Live Resolution Check (dunkinbrands.com subdomains) ---" | tee -a "$OUTDIR/results.txt"
if [ -f "$OUTDIR/subdomains-dunkinbrands.txt" ]; then
  while IFS= read -r domain; do
    # Skip bare domain, wildcard, and email lines
    [[ "$domain" == "dunkinbrands.com" ]] && continue
    [[ "$domain" == *"*"* ]] && continue
    [[ "$domain" == *"@"* ]] && continue
    a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -1)
    cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
    if [ -n "$cname" ]; then
      echo "LIVE  $domain → CNAME $cname (A: ${a:-unresolved})" | tee -a "$OUTDIR/results.txt"
    elif [ -n "$a" ]; then
      echo "LIVE  $domain → A $a" | tee -a "$OUTDIR/results.txt"
    else
      echo "DEAD  $domain" | tee -a "$OUTDIR/results.txt"
    fi
  done < "$OUTDIR/subdomains-dunkinbrands.txt"
fi

# === RESOLUTION CHECK — dunkindonuts.com subdomains ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- Live Resolution Check (dunkindonuts.com subdomains) ---" | tee -a "$OUTDIR/results.txt"
if [ -f "$OUTDIR/subdomains-dunkindonuts.txt" ]; then
  while IFS= read -r domain; do
    [[ "$domain" == "dunkindonuts.com" ]] && continue
    [[ "$domain" == *"*"* ]] && continue
    [[ "$domain" == *"@"* ]] && continue
    a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -1)
    cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
    if [ -n "$cname" ]; then
      echo "LIVE  $domain → CNAME $cname (A: ${a:-unresolved})" | tee -a "$OUTDIR/results.txt"
    elif [ -n "$a" ]; then
      echo "LIVE  $domain → A $a" | tee -a "$OUTDIR/results.txt"
    else
      echo "DEAD  $domain" | tee -a "$OUTDIR/results.txt"
    fi
  done < "$OUTDIR/subdomains-dunkindonuts.txt"
fi

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
