#!/usr/bin/env bash
# Sanity-checks the SOPS secret files without printing any secret value.
set -euo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

for f in $(git ls-files --cached --others --exclude-standard | grep -E '\.sops(\.(ya?ml|env|json))?$' | grep -v '^\.sops\.yaml$'); do
  # yaml/env: "sops:" / "sops_version=" metadata; binary/json: a top-level "sops" object
  if ! grep -q 'ENC\[' "$f" || ! grep -qE '^(sops:|sops_version=)|"sops": *\{' "$f"; then
    echo "NOT ENCRYPTED: $f"; exit 1
  fi
  echo "encrypted: $f"
done

if [ ! -f "${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}" ]; then
  echo "no age key available (e.g. CI): skipping content checks"
  exit 0
fi

sops decrypt secrets/homelab.sops.yml | python3 -c '
import sys, yaml
d = yaml.safe_load(sys.stdin)
print("keys:", ", ".join(sorted(d)))
print("wireguard peers:", d["wireguard_wg0_conf"].count("[Peer]"))
print("adguard: refs to old NPM .214:", d["adguard_config_yaml"].count("192.168.0.214"),
      "| refs to apps .85:", d["adguard_config_yaml"].count("192.168.0.85"))
'
