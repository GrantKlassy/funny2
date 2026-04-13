#!/usr/bin/env bash
# 07-gibberish-analysis.sh — encoding tests and keyboard distribution analysis
set -euo pipefail

LINES=(
  "Wjkhsgjkhdgkhkjfhgdfgdogihdgcatmomdfgddgjkk"
  "kidogsyjkdffkkjkddadadadadadadadamommmmmmmdf"
  "d7766Vvvqg8888"
  "AAAAAAAAAaaaaaasssvIFFGHF7ghfh88"
  "fgkhdfgjkhdfkgnsdklhw8978478w4899wu0t8tml2znkvjgiahofh"
  "kafullJAUISGSIUHGDSIHjlo8q87668ydghdlkjkhdffj"
  "mamamama dad dad dad momm mom mom mommm78499"
)

echo "=== Base64 decode attempts ==="
for L in "${LINES[@]}"; do
  echo "--- $L ---"
  echo "$L" | base64 -d 2>/dev/null | xxd | head -3
  echo ""
done

echo "=== ROT13 ==="
for L in "${LINES[@]}"; do
  echo "ROT13: $(echo "$L" | tr 'a-zA-Z' 'n-za-mN-ZA-M')"
done

echo -e "\n=== Keyboard row analysis ==="
GIBBERISH="${LINES[0]}${LINES[1]}"
TOTAL=${#GIBBERISH}
TOP=$(echo "$GIBBERISH" | tr -cd 'qwertyuiopQWERTYUIOP' | wc -c)
HOME=$(echo "$GIBBERISH" | tr -cd 'asdfghjklASDFGHJKL' | wc -c)
BOTTOM=$(echo "$GIBBERISH" | tr -cd 'zxcvbnmZXCVBNM' | wc -c)
echo "Total: $TOTAL | Top: $TOP ($(( TOP * 100 / TOTAL ))%) | Home: $HOME ($(( HOME * 100 / TOTAL ))%) | Bottom: $BOTTOM ($(( BOTTOM * 100 / TOTAL ))%)"

echo -e "\n=== Embedded word search ==="
FULL="${LINES[0]}${LINES[1]}"
for WORD in cat dog kid mom dad mama dada go do if; do
  COUNT=$(echo "$FULL" | grep -oi "$WORD" | wc -l)
  [ "$COUNT" -gt 0 ] && echo "FOUND: \"$WORD\" x$COUNT"
done
