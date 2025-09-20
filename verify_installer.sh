#!/usr/bin/env bash
set -Eeuo pipefail

INSTALLER="install_msmtp_armored.sh"
MODULE_DIR="modules"
errors=0

echo "🔍  Validating coherence of $INSTALLER …"
echo

# 1. Modules invoked (bash + source)
echo "• Modules invoked:"
# Regex that captures any '$MODULES_DIR/<script>.sh' within bash "" or source ""
grep -oP '\$MODULES_DIR/\K[^") ]+\.sh' "$INSTALLER" | sort -u |
while read -r module; do
  printf "  - %s … " "$module"
  if [[ -f "$MODULE_DIR/$module" ]]; then
    echo "OK"
  else
    echo "❌ MISSING"
    errors=$((errors+1))
  fi
done
echo

# 2. Functions invoked
echo "• Functions invoked:"
# Extracts all tokens foo(, filters common patterns and leaves only possible functions from our code
grep -oP '\b[a-zA-Z_][a-zA-Z0-9_]*(?=\s*\()' "$INSTALLER" |
grep -vE '^(if|while|for|echo|read|source|bash|exit|printf)$' |
sort -u |
while read -r func; do
  printf "  - %s() … " "$func"
  if grep -R -qE "^\s*${func}\s*\(\)" "$MODULE_DIR" "$MODULE_DIR/utils.sh"; then
    echo "OK"
  else
    echo "⚠️  NOT DEFINED"
  fi
done
echo

if (( errors > 0 )); then
  echo "❌  Detected $errors missing module(s). Fix the installer or add the module file."
  exit 1
else
  echo "✅  Installer and modules are coherent."
fi
