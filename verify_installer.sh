#!/usr/bin/env bash
set -Eeuo pipefail

INSTALLER="install_msmtp_armored.sh"
MODULE_DIR="modules"
errors=0

echo "🔍  Validating coherence of $INSTALLER …"
echo

# 1. Sourced modules
echo "• Sourced modules:"
grep -oP 'bash "\$MODULES_DIR/\K[^"]+' "$INSTALLER" | sort -u | while read -r module; do
  printf "  - %s … " "$module"
  if [[ -f "$MODULE_DIR/$module" ]]; then
    echo "OK"
  else
    echo "❌ MISSING"
    errors=$((errors+1))
  fi
done
echo

# 2. Invoked functions
echo "• Invoked functions:"
# extract tokens like foo( and filter control-flows and internal commands
grep -oP '\b\w+(?=\()' "$INSTALLER" \
  | grep -vE '^(if|while|for|echo|read|source|bash)$' \
  | sort -u \
  | while read -r func; do
    printf "  - %s() … " "$func"
    if grep -R -qE "^\s*${func}\s*\(\)" "$MODULE_DIR" "$MODULE_DIR/utils.sh"; then
      echo "OK"
    else
      echo "⚠️  NOT DEFINED"
    fi
  done
echo

if (( errors > 0 )); then
  echo "❌  Missing module(s) $errors were detected."
  exit 1
else
  echo "✅  Coherence verified without errors."
fi
