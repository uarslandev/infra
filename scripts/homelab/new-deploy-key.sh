#!/usr/bin/env bash
# Generates an SSH deploy key straight into secrets/homelab.sops.yml and prints only the PUBLIC key.
# The private key exists in plain text only in /dev/shm (RAM) and is removed on exit.
#   scripts/homelab/new-deploy-key.sh <secret_name> <comment>
# Example: scripts/homelab/new-deploy-key.sh apex_deploy_key homelab-apps-apex
# Then add the printed public key to the GitHub repo as a READ-ONLY deploy key.
set -euo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

name=${1:?usage: new-deploy-key.sh <secret_name> <comment>}
comment=${2:?usage: new-deploy-key.sh <secret_name> <comment>}
file=secrets/homelab.sops.yml
[[ $name =~ ^[a-z][a-z0-9_]*$ ]] || { echo "name must be snake_case"; exit 1; }

if sops decrypt --extract "[\"$name\"]" "$file" >/dev/null 2>&1; then
  echo "$name already exists in $file; remove it first (sops $file) to rotate"; exit 1
fi

tmp=$(mktemp -d /dev/shm/deploykey.XXXXXX); chmod 700 "$tmp"; trap 'rm -rf "$tmp"' EXIT
ssh-keygen -q -t ed25519 -N "" -C "$comment" -f "$tmp/key"
python3 -c 'import json, sys; print(json.dumps(open(sys.argv[1]).read()))' "$tmp/key" > "$tmp/value.json"
sops set --value-file "$file" "[\"$name\"]" "$tmp/value.json"

echo "Saved the private key as $name in $file (value hidden). Public key:"
cat "$tmp/key.pub"
