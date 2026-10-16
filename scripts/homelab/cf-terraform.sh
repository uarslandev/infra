#!/usr/bin/env bash
# Runs terraform in terraform/cloudflare with credentials from secrets/homelab.sops.yml, decrypted in memory only:
#   CLOUDFLARE_API_TOKEN  <- cloudflare_terraform_api_token (make set-secret NAME=cloudflare_terraform_api_token)
#   TF_VAR_account_id/tunnel_id <- cloudflared_tunnel_token (base64 JSON {"a": account, "t": tunnel, "s": secret})
#   TF_VAR_zone_name      <- domain of jellyfin_published_url (same rule as homelab_public_domain in Ansible)
#   scripts/homelab/cf-terraform.sh plan -out=tfplan.tfplan     (or: make cf-plan / make cf-apply)
set -euo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

# Values stay in this process's environment; nothing is written to disk or printed.
env_lines=$(sops decrypt secrets/homelab.sops.yml | python3 -c '
import base64, json, shlex, sys, yaml
from urllib.parse import urlsplit
d = yaml.safe_load(sys.stdin)
if not d.get("cloudflare_terraform_api_token"):
    sys.exit("cloudflare_terraform_api_token missing: make set-secret NAME=cloudflare_terraform_api_token")
t = json.loads(base64.b64decode(d["cloudflared_tunnel_token"] + "==="))
env = {
    "CLOUDFLARE_API_TOKEN": d["cloudflare_terraform_api_token"],
    "TF_VAR_account_id": t["a"],
    "TF_VAR_tunnel_id": t["t"],
    "TF_VAR_zone_name": urlsplit(d["jellyfin_published_url"]).hostname.split(".", 1)[1],
}
for k, v in env.items():
    print(f"export {k}={shlex.quote(v)}")
')
eval "$env_lines"
unset env_lines

cd terraform/cloudflare
exec terraform "$@"
