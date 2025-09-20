#!/usr/bin/env bash
set -Eeuo pipefail

INSTALLER="install_msmtp_armored.sh"
MODULE_DIR="modules"
UTILS_FILE="$MODULE_DIR/utils.sh"
errors=0

echo "🔍  Validating coherence of $INSTALLER …"
echo

# 1. Modules invoked (bash + source)
echo "• Modules invoked:"
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

# 2. Functions invoked (with or without parentheses)
echo "• Functions invoked:"
grep -oP '\b[a-zA-Z_][a-zA-Z0-9_]*(?=\s*\(|\b)' "$INSTALLER" |
grep -vE '^(if|then|else|fi|while|for|do|done|echo|read|source|bash|exit|printf|cd|ls|true|false)$' |
grep -vP '^[A-Z0-9_]+$' |   # ignores constants like ACCOUNT, HOST, etc.
grep -vP '^".*"$' |         # ignores strings in double quotes
grep -vP "'.*'" |           # ignores strings in single quotes
sort -u |
while read -r func; do
  printf "  - %s() … " "$func"
  if grep -R -qE "^\s*${func}\s*\(\)" "$MODULE_DIR" "$UTILS_FILE"; then
    echo "OK"
  else
    echo "⚠️  NOT DEFINED"
    grep -nE "(^|[^a-zA-Z0-9_])${func}(\s|\(|$)" "$INSTALLER" | sed "s/^/     /"
    suggestion=$(grep -R -hE '^[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)' "$MODULE_DIR" "$UTILS_FILE" \
      | sed 's/().*//' \
      | grep -v "^$func$" \
      | awk -v target="$func" '
        function levenshtein(a,b) {
          n=length(a); m=length(b)
          for (i=0;i<=n;i++) d[i,0]=i
          for (j=0;j<=m;j++) d[0,j]=j
          for (i=1;i<=n;i++) {
            ai=substr(a,i,1)
            for (j=1;j<=m;j++) {
              bj=substr(b,j,1)
              cost=(ai==bj)?0:1
              d[i,j]=min(d[i-1,j]+1, min(d[i,j-1]+1, d[i-1,j-1]+cost))
            }
          }
          return d[n,m]
        }
        function min(x,y){ return x<y?x:y }
        BEGIN { best=""; bestdist=999 }
        {
          dist=levenshtein(target,$0)
          if (dist<bestdist) { best=$0; bestdist=dist }
        }
        END { if (bestdist<=3) print best }
      ')
    if [[ -n "$suggestion" ]]; then
      echo "     💡 Did you mean: $suggestion ?"
    fi
  fi
done
echo

if (( errors > 0 )); then
  echo "❌  Detected $errors missing module(s). Fix the installer or add the module file."
  exit 1
else
  echo "✅  Installer and modules are coherent."
fi
