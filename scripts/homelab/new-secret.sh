#!/usr/bin/env bash
# Generates a random secret and stores it in secrets/homelab.sops.yml without ever printing it.
#   scripts/homelab/new-secret.sh <name> [length]      (or: make secret NAME=<name> [LENGTH=<n>])
# Read it later with: sops decrypt --extract '["<name>"]' secrets/homelab.sops.yml
set -euo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

name=${1:?usage: new-secret.sh <name> [length]}
length=${2:-40}
file=secrets/homelab.sops.yml

[[ $name =~ ^[a-z][a-z0-9_]*$ ]] || { echo "name must be snake_case, e.g. paperless_db_password"; exit 1; }
if sops decrypt --extract "[\"$name\"]" "$file" >/dev/null 2>&1; then
  echo "$name already exists in $file (edit it with: sops $file)"; exit 1
fi

# Alphanumeric only: safe in .env files, URLs and shell without quoting issues.
value=$(python3 -c 'import secrets, string, sys; a = string.ascii_letters + string.digits; print("".join(secrets.choice(a) for _ in range(int(sys.argv[1]))))' "$length")
sops set "$file" "[\"$name\"]" "\"$value\""
echo "added $name ($length chars) to $file; use it as {{ $name }} in roles/stacks/templates/<stack>.env.j2"
