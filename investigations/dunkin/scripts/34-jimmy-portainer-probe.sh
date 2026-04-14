#!/bin/bash
# Jimmy John's Docker/Portainer & DevOps exposure probe
# CT logs revealed dev-portainer, docker, bitbucket, jira, hipchat, tableau, WSUS subdomains
# Run: podman run --rm --dns 8.8.8.8 \
#   -v ./investigations/dunkin/scripts:/work/scripts:z \
#   -v ./investigations/dunkin/artifacts/jimmy-portainer-2026-04-13:/out:Z \
#   investigator bash /work/scripts/34-jimmy-portainer-probe.sh
set -uo pipefail

OUTDIR="/out"
mkdir -p "$OUTDIR"

echo "=== JIMMY JOHN'S DOCKER/PORTAINER & DEVOPS EXPOSURE PROBE ===" | tee "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
echo "" | tee -a "$OUTDIR/results.txt"

# === HIGH-VALUE TARGETS: DevOps infrastructure ===
DEVOPS_TARGETS=(
  "dev-portainer.jimmyjohns.com"
  "docker.jimmyjohns.com"
  "bitbucket.jimmyjohns.com"
  "jira.jimmyjohns.com"
  "hipchat.jimmyjohns.com"
  "tableau.jimmyjohns.com"
  "intranet.jimmyjohns.com"
)

echo "--- HIGH-VALUE DevOps DNS Resolution ---" | tee -a "$OUTDIR/results.txt"
for domain in "${DEVOPS_TARGETS[@]}"; do
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
  echo "$domain  A: ${a:-NXDOMAIN}  CNAME: ${cname:-none}" | tee -a "$OUTDIR/results.txt"
done

# === OTHER INTERESTING TARGETS ===
OTHER_TARGETS=(
  "vpn.jimmyjohns.com"
  "drvpn.jimmyjohns.com"
  "remotesupport.jimmyjohns.com"
  "WSUS.JIMMYJOHNS.COM"
  "jj-fortiems.jimmyjohns.com"
  "duodag.jimmyjohns.com"
  "ektron.jimmyjohns.com"
  "jimmystore.jimmyjohns.com"
  "securelogin.jimmyjohns.com"
  "jj-dropbox.jimmyjohns.com"
  "rodc.jimmyjohns.com"
)

echo "" | tee -a "$OUTDIR/results.txt"
echo "--- OTHER INTERESTING DNS Resolution ---" | tee -a "$OUTDIR/results.txt"
for domain in "${OTHER_TARGETS[@]}"; do
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
  echo "$domain  A: ${a:-NXDOMAIN}  CNAME: ${cname:-none}" | tee -a "$OUTDIR/results.txt"
done

# === REMAINING SUBDOMAINS QUICK DNS SWEEP ===
ALL_SUBS=(
  "api-idp.jimmyjohns.com"
  "api-rap.jimmyjohns.com"
  "api.jimmyjohns.com"
  "api.locations.jimmyjohns.com"
  "api2.jimmyjohns.com"
  "apps.jimmyjohns.com"
  "apps01.jimmyjohns.com"
  "assets.locations.jimmyjohns.com"
  "auth.jimmyjohns.com"
  "aw-cg.jimmyjohns.com"
  "careers.jimmyjohns.com"
  "catalog.jimmyjohns.com"
  "chat.jimmyjohns.com"
  "chatdev.jimmyjohns.com"
  "chattest.jimmyjohns.com"
  "core.jimmyjohns.com"
  "core01.jimmyjohns.com"
  "dev01.jimmyjohns.com"
  "dropbox.jimmyjohns.com"
  "e.jimmyjohns.com"
  "echo.jimmyjohns.com"
  "enterprise.jimmyjohns.com"
  "feedback.jimmyjohns.com"
  "gear.jimmyjohns.com"
  "guest.jimmyjohns.com"
  "IC3.jimmyjohns.com"
  "jj-ccentral.jimmyjohns.com"
  "jjsfw.jimmyjohns.com"
  "link.jimmyjohns.com"
  "locations.jimmyjohns.com"
  "mail.jimmyjohns.com"
  "maps.locations.jimmyjohns.com"
  "mgr.jimmyjohns.com"
  "mi.jimmyjohns.com"
  "mx1.jimmyjohns.com"
  "online.jimmyjohns.com"
  "order.jimmyjohns.com"
  "ot1.jimmyjohns.com"
  "owners.jimmyjohns.com"
  "preview.jimmyjohns.com"
  "preview3.jimmyjohns.com"
  "print.jimmyjohns.com"
  "printingcatalog.jimmyjohns.com"
  "pullzone.jimmyjohns.com"
  "qr.jimmyjohns.com"
  "rstatic.locations.jimmyjohns.com"
  "seg.jimmyjohns.com"
  "services.jimmyjohns.com"
  "services01.jimmyjohns.com"
  "sidevouchers.jimmyjohns.com"
  "sites.jimmyjohns.com"
  "staging.jimmyjohns.com"
  "store.jimmyjohns.com"
  "support.jimmyjohns.com"
  "CDN.jimmyjohns.com"
  "www.jimmyjohns.com"
  "www.careers.jimmyjohns.com"
  "www.sidevouchers.jimmyjohns.com"
)

echo "" | tee -a "$OUTDIR/results.txt"
echo "--- FULL SUBDOMAIN DNS SWEEP ---" | tee -a "$OUTDIR/results.txt"
LIVE_SUBS=()
for domain in "${ALL_SUBS[@]}"; do
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  if [ -n "$a" ]; then
    cname=$(dig +short "$domain" CNAME @8.8.8.8 2>/dev/null | head -1)
    echo "LIVE: $domain  A: $a  CNAME: ${cname:-none}" | tee -a "$OUTDIR/results.txt"
    LIVE_SUBS+=("$domain")
  else
    echo "DEAD: $domain" | tee -a "$OUTDIR/results.txt"
  fi
done

# === HTTP PROBE: DevOps targets that resolved ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- HTTP PROBE: DevOps Targets ---" | tee -a "$OUTDIR/results.txt"
for domain in "${DEVOPS_TARGETS[@]}"; do
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -1)
  if [ -z "$a" ]; then
    echo "[$domain] SKIP — no DNS" | tee -a "$OUTDIR/results.txt"
    continue
  fi
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "[$domain] HTTPS probe:" | tee -a "$OUTDIR/results.txt"
  status=$(curl -sk --max-time 15 -o /dev/null -w '%{http_code}' "https://$domain/" 2>/dev/null)
  echo "  Status: $status" | tee -a "$OUTDIR/results.txt"
  if [ "$status" != "000" ]; then
    curl -sk --max-time 15 -D "$OUTDIR/${domain}-headers.txt" -o "$OUTDIR/${domain}-body.html" "https://$domain/" 2>/dev/null
    head -20 "$OUTDIR/${domain}-headers.txt" 2>/dev/null | tee -a "$OUTDIR/results.txt"
    size=$(wc -c < "$OUTDIR/${domain}-body.html" 2>/dev/null)
    echo "  Body size: ${size:-0} bytes" | tee -a "$OUTDIR/results.txt"
    head -5 "$OUTDIR/${domain}-body.html" 2>/dev/null | tee -a "$OUTDIR/results.txt"
  fi
  # HTTP too
  status_http=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' "http://$domain/" 2>/dev/null)
  echo "  HTTP status: $status_http" | tee -a "$OUTDIR/results.txt"
done

# === PORTAINER-SPECIFIC PATHS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- PORTAINER-SPECIFIC PATH SWEEP ---" | tee -a "$OUTDIR/results.txt"
PORTAINER_PATHS=("/" "/api/status" "/api/endpoints" "/api/settings/public" "/api/system/status" "/api/system/version")
for domain in "dev-portainer.jimmyjohns.com" "docker.jimmyjohns.com"; do
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -1)
  if [ -z "$a" ]; then
    echo "[$domain] SKIP — no DNS" | tee -a "$OUTDIR/results.txt"
    continue
  fi
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "[$domain] Portainer path sweep:" | tee -a "$OUTDIR/results.txt"
  for path in "${PORTAINER_PATHS[@]}"; do
    status=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' "https://$domain$path" 2>/dev/null)
    echo "  $path → $status" | tee -a "$OUTDIR/results.txt"
  done
  # Also try port 9000 (Portainer default)
  echo "  Port 9000:" | tee -a "$OUTDIR/results.txt"
  status9000=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' "https://$domain:9000/" 2>/dev/null)
  echo "  :9000/ → $status9000" | tee -a "$OUTDIR/results.txt"
  status9000h=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' "http://$domain:9000/" 2>/dev/null)
  echo "  :9000/ (HTTP) → $status9000h" | tee -a "$OUTDIR/results.txt"
done

# === DOCKER REGISTRY PATHS ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- DOCKER REGISTRY PATH SWEEP ---" | tee -a "$OUTDIR/results.txt"
REGISTRY_PATHS=("/v2/" "/v2/_catalog")
for domain in "docker.jimmyjohns.com" "dev-portainer.jimmyjohns.com"; do
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -1)
  if [ -z "$a" ]; then continue; fi
  echo "[$domain] Registry paths:" | tee -a "$OUTDIR/results.txt"
  for path in "${REGISTRY_PATHS[@]}"; do
    status=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' "https://$domain$path" 2>/dev/null)
    echo "  $path → $status" | tee -a "$OUTDIR/results.txt"
  done
done

# === TLS CERTS for DevOps targets ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- TLS CERTIFICATES ---" | tee -a "$OUTDIR/results.txt"
for domain in "${DEVOPS_TARGETS[@]}"; do
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -1)
  if [ -z "$a" ]; then continue; fi
  echo "" | tee -a "$OUTDIR/results.txt"
  echo "[$domain] TLS cert:" | tee -a "$OUTDIR/results.txt"
  echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null | tee -a "$OUTDIR/results.txt"
done

# === NMAP for Portainer/Docker targets ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- NMAP SERVICE DETECTION ---" | tee -a "$OUTDIR/results.txt"
for domain in "dev-portainer.jimmyjohns.com" "docker.jimmyjohns.com"; do
  a=$(dig +short "$domain" A @8.8.8.8 2>/dev/null | head -1)
  if [ -z "$a" ]; then
    echo "[$domain] SKIP — no DNS" | tee -a "$OUTDIR/results.txt"
    continue
  fi
  echo "[$domain] nmap -sV -p 80,443,2375,2376,8000,9000 $a:" | tee -a "$OUTDIR/results.txt"
  nmap -sV -p 80,443,2375,2376,8000,9000 "$a" 2>/dev/null | tee -a "$OUTDIR/results.txt"
done

# === HTTP STATUS SWEEP: All live subdomains ===
echo "" | tee -a "$OUTDIR/results.txt"
echo "--- HTTP STATUS SWEEP: All Live Subdomains ---" | tee -a "$OUTDIR/results.txt"
# Combine devops + other targets that resolved
for domain in "${LIVE_SUBS[@]}"; do
  status=$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' "https://$domain/" 2>/dev/null)
  echo "  $domain → $status" | tee -a "$OUTDIR/results.txt"
done

echo "" | tee -a "$OUTDIR/results.txt"
echo "=== PROBE COMPLETE ===" | tee -a "$OUTDIR/results.txt"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUTDIR/results.txt"
