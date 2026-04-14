#!/bin/bash
# Email infrastructure mapping: Salesforce MC stack, cross-brand comparison
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/email-infrastructure-2026-04-13:/out:Z \
#   investigator bash /work/scripts/30-email-infrastructure.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== EMAIL INFRASTRUCTURE MAPPING ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# === DUNKIN EMAIL SUBDOMAINS ===
echo "--- Dunkin Email Subdomains ---" | tee -a "$OUTDIR/results.txt"
EMAIL_SUBS=(
  "click.emailinfo.dunkindonuts.com|Salesforce MC Click Tracker"
  "cloud.emailinfo.dunkindonuts.com|Salesforce MC Cloud"
  "image.emailinfo.dunkindonuts.com|Salesforce MC Image Host"
  "view.emailinfo.dunkindonuts.com|Salesforce MC View Tracker"
  "amp.news.dunkindonuts.com|AMP for Email (News)"
  "news.dunkindonuts.com|News"
  "emails.dunkindonuts.com|Emails"
  "mi.dunkindonuts.com|Marketing Intelligence?"
  "email.dunkindonuts.com|Email"
  "mail.dunkindonuts.com|Mail"
)

for entry in "${EMAIL_SUBS[@]}"; do
  domain=$(echo "$entry" | cut -d'|' -f1)
  label=$(echo "$entry" | cut -d'|' -f2)
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)

  if [ -n "$cname" ] || [ -n "$a" ]; then
    echo "LIVE  $domain ($label)" | tee -a "$OUTDIR/results.txt"
    echo "  CNAME: ${cname:-none} A: ${a:-none}" | tee -a "$OUTDIR/results.txt"

    # HTTP probe
    http=$(curl -sk --max-time 8 -o /dev/null -w '%{http_code}' "https://$domain/" 2>/dev/null)
    echo "  HTTPS: $http" | tee -a "$OUTDIR/results.txt"

    # Headers
    curl -sk --max-time 8 -I "https://$domain/" 2>/dev/null | grep -iE '^(server|x-powered|x-request|content-type|location):' | tee -a "$OUTDIR/results.txt" || true
  else
    echo "DEAD  $domain ($label)" | tee -a "$OUTDIR/results.txt"
  fi
done

# === CROSS-BRAND SPF ANALYSIS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"
echo "CROSS-BRAND EMAIL VENDOR COMPARISON" | tee -a "$OUTDIR/results.txt"
echo "========================================" | tee -a "$OUTDIR/results.txt"

BRANDS=(
  "dunkindonuts.com"
  "baskinrobbins.com"
  "arbys.com"
  "buffalowildwings.com"
  "sonicdrivein.com"
  "jimmyjohns.com"
  "inspirebrands.com"
)

for brand in "${BRANDS[@]}"; do
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "[$brand]" | tee -a "$OUTDIR/results.txt"

  # MX
  echo "  MX:" | tee -a "$OUTDIR/results.txt"
  dig +short "$brand" MX @8.8.8.8 2>/dev/null | sort | sed 's/^/    /' | tee -a "$OUTDIR/results.txt"

  # SPF
  echo "  SPF:" | tee -a "$OUTDIR/results.txt"
  dig +short "$brand" TXT @8.8.8.8 2>/dev/null | grep -i spf | sed 's/^/    /' | tee -a "$OUTDIR/results.txt"

  # DMARC
  echo "  DMARC:" | tee -a "$OUTDIR/results.txt"
  dig +short "_dmarc.$brand" TXT @8.8.8.8 2>/dev/null | sed 's/^/    /' | tee -a "$OUTDIR/results.txt"

  # Extract SPF includes (reveals email vendors)
  spf=$(dig +short "$brand" TXT @8.8.8.8 2>/dev/null | grep -i spf | tr -d '"')
  if [ -n "$spf" ]; then
    echo "  Authorized Senders (from SPF):" | tee -a "$OUTDIR/results.txt"
    echo "$spf" | grep -oP 'include:\S+' | sed 's/^/    /' | tee -a "$OUTDIR/results.txt"
    echo "$spf" | grep -oP 'ip4:\S+' | sed 's/^/    /' | tee -a "$OUTDIR/results.txt"
  fi

  # Check for email tracking subdomains
  for sub in "click.emailinfo" "cloud.emailinfo" "image.emailinfo" "emails" "email" "news"; do
    a=$(dig +short "$sub.$brand" A @8.8.8.8 2>/dev/null | head -1)
    cname=$(dig +short "$sub.$brand" CNAME @8.8.8.8 2>/dev/null | head -1)
    if [ -n "$a" ] || [ -n "$cname" ]; then
      echo "  $sub.$brand → ${cname:-$a}" | tee -a "$OUTDIR/results.txt"
    fi
  done
done

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== DONE ===" | tee -a "$OUTDIR/results.txt"
echo "Completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
