#!/usr/bin/env bash
# Builds the SOPS-encrypted secret files from the live system (run once, from the admin PC / WSL).
# Never prints secret values; plaintext only exists in /dev/shm (RAM) and is removed on exit.
#
#   scripts/homelab/bootstrap-secrets.sh          # both parts
#   scripts/homelab/bootstrap-secrets.sh token    # only the Proxmox API token for Terraform
#   scripts/homelab/bootstrap-secrets.sh services # only the service secrets
#   scripts/homelab/bootstrap-secrets.sh grafana  # random Grafana admin password (only if missing)
#   scripts/homelab/bootstrap-secrets.sh pve-exporter # read-only Proxmox token for monitoring
set -euo pipefail
REPO=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
PART=${1:-all}
TMP=$(mktemp -d /dev/shm/secrets.XXXXXX)
chmod 700 "$TMP"
trap 'rm -rf "$TMP"' EXIT

# 1) Proxmox API token for Terraform (dedicated user terraform@pve, not root@pam)
if [[ $PART == all || $PART == token ]]; then
  ssh -o BatchMode=yes proxmox '
    pveum user list --output-format json | grep -q "\"terraform@pve\"" || pveum user add terraform@pve --comment "Terraform (homelab-as-code)"
    pveum acl modify / --users terraform@pve --roles Administrator
    pveum user token remove terraform@pve tf >/dev/null 2>&1 || true
    pveum user token add terraform@pve tf --privsep 0 --output-format json' > "$TMP/token.json"
  python3 - "$TMP/token.json" > "$TMP/tf.env" <<'PY'
import json, sys
t = json.load(open(sys.argv[1]))
print(f"PROXMOX_VE_API_TOKEN={t['full-tokenid']}={t['value']}")
PY
  mkdir -p "$REPO/terraform/proxmox"
  cp "$TMP/tf.env" "$REPO/terraform/proxmox/secrets.sops.env"
  (cd "$REPO" && sops encrypt --in-place terraform/proxmox/secrets.sops.env)
  echo "wrote terraform/proxmox/secrets.sops.env"
fi

# 2) Service secrets taken over from the old servarr/LXC configs
if [[ $PART == all || $PART == services ]] && [[ -f $REPO/secrets/homelab.sops.yml && ${FORCE:-0} != 1 ]]; then
  echo "secrets/homelab.sops.yml exists; not overwriting it (FORCE=1 to rebuild it from the legacy configs)"
elif [[ $PART == all || $PART == services ]]; then
  ssh -o BatchMode=yes proxmox '
    cd /tank/dockge/stacks
    cat immich/.env;               echo "---SPLIT---"
    cat nextcloud/.env;            echo "---SPLIT---"
    cat cloudflared/compose.yaml;  echo "---SPLIT---"
    cat jellyfin/compose.yaml;     echo "---SPLIT---"
    tar -xzOf /tank/legacy/lxc-adguard/opt-AdGuardHome.tgz AdGuardHome/AdGuardHome.yaml; echo "---SPLIT---"
    tar -xzOf /tank/legacy/lxc-wireguard/wireguard.tgz etc/wireguard/wg0.conf' > "$TMP/raw"
  python3 - "$TMP/raw" > "$TMP/homelab.sops.yml" <<'PY'
import re, sys, yaml
immich, nextcloud, cfd, jelly, adguard, wg = open(sys.argv[1]).read().split("---SPLIT---\n")
def env(text):
    out = {}
    for line in text.splitlines():
        m = re.match(r"^\s*([A-Z_]+)=(.*)$", line)
        if m:
            out[m.group(1)] = m.group(2).strip().strip('"').strip("'")
    return out
i, n = env(immich), env(nextcloud)
vals = {
    "immich_db_password": i["DB_PASSWORD"],
    "nextcloud_mysql_root_password": n["MYSQL_ROOT_PASSWORD"],
    "nextcloud_mysql_password": n["MYSQL_PASSWORD"],
    "cloudflared_tunnel_token": re.search(r"TUNNEL_TOKEN[:=]\s*['\"]?([A-Za-z0-9+/=_-]+)", cfd).group(1),
    "jellyfin_published_url": re.search(r"JELLYFIN_PublishedServerUrl=(\S+)", jelly).group(1),
    # NPM moved from its own LXC (.214) to the apps VM (.85): repoint AdGuard DNS rewrites.
    "adguard_config_yaml": adguard.replace("192.168.0.214", "192.168.0.85"),
    "wireguard_wg0_conf": wg,
}
for k, v in vals.items():
    assert v, k
yaml.safe_dump(vals, sys.stdout, default_flow_style=False, width=4096)
PY
  mkdir -p "$REPO/secrets"
  cp "$TMP/homelab.sops.yml" "$REPO/secrets/homelab.sops.yml"
  (cd "$REPO" && sops encrypt --in-place secrets/homelab.sops.yml)
  echo "wrote secrets/homelab.sops.yml with keys:"
  grep -oE '^[a-z_]+:' "$REPO/secrets/homelab.sops.yml" | grep -v '^sops:'
fi

# Adds one key to secrets/homelab.sops.yml without printing the value.
sops_set() {
  (cd "$REPO" && sops set secrets/homelab.sops.yml "[\"$1\"]" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$2")")
  echo "set $1 in secrets/homelab.sops.yml"
}
has_key() {
  (cd "$REPO" && sops decrypt --extract "[\"$1\"]" secrets/homelab.sops.yml >/dev/null 2>&1)
}

# 3) Grafana admin password (generated, never shown; read it with:
#    sops decrypt --extract '["grafana_admin_password"]' secrets/homelab.sops.yml)
if [[ $PART == all || $PART == grafana ]]; then
  if has_key grafana_admin_password; then
    echo "grafana_admin_password already set"
  else
    sops_set grafana_admin_password "$(openssl rand -base64 30 | tr -d '\n/+=')"
  fi
fi

# 4) Read-only Proxmox API token for prometheus-pve-exporter (role PVEAuditor)
if [[ $PART == all || $PART == pve-exporter ]]; then
  ssh -o BatchMode=yes proxmox '
    pveum user list --output-format json | grep -q "\"pve-exporter@pve\"" || pveum user add pve-exporter@pve --comment "Prometheus exporter (read-only)"
    pveum acl modify / --users pve-exporter@pve --roles PVEAuditor
    pveum user token remove pve-exporter@pve monitoring >/dev/null 2>&1 || true
    pveum user token add pve-exporter@pve monitoring --privsep 0 --output-format json' > "$TMP/pve-exporter.json"
  sops_set pve_exporter_token_value "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["value"])' "$TMP/pve-exporter.json")"
fi
