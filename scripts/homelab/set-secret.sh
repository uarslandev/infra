#!/usr/bin/env bash
# Stores a secret you already have (API token, app password) in secrets/homelab.sops.yml.
# Asks for the value with hidden input: it is never shown, echoed, logged or passed on the command line.
#   scripts/homelab/set-secret.sh <name>      (or: make set-secret NAME=<name>)
set -euo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

name=${1:?usage: set-secret.sh <name>}
file=secrets/homelab.sops.yml
[[ $name =~ ^[a-z][a-z0-9_]*$ ]] || { echo "name must be snake_case"; exit 1; }

if sops decrypt --extract "[\"$name\"]" "$file" >/dev/null 2>&1; then
  echo "Note: $name already exists and will be replaced."
fi

read -rsp "Paste the value for $name (input is hidden), then press Enter: " value; echo
read -rsp "Paste it again to confirm: " again; echo
[[ -n $value ]] || { echo "empty value, nothing changed"; exit 1; }
[[ $value == "$again" ]] || { echo "values differ, nothing changed"; exit 1; }
value=${value//[[:space:]]/} # tokens/app passwords never contain whitespace

# The value goes to sops via a temp file in RAM, not via argv (argv is visible in the process list).
tmp=$(mktemp /dev/shm/secret.XXXXXX); trap 'rm -f "$tmp"' EXIT
printf '%s' "$value" | python3 -c 'import json, sys; print(json.dumps(sys.stdin.read()))' > "$tmp"
sops set --value-file "$file" "[\"$name\"]" "$tmp"
unset value again

echo "Saved $name (${#name} char name, value hidden) in $file."
git diff --stat -- "$file"
