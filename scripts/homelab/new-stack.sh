#!/usr/bin/env bash
# Scaffolds a new Docker Compose stack for the apps VM.
#   scripts/homelab/new-stack.sh <name> <image:tag> <container-port>
# Example: scripts/homelab/new-stack.sh paperless ghcr.io/paperless-ngx/paperless-ngx:2.20.3 8000
set -euo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

name=${1:?usage: new-stack.sh <name> <image:tag> <container-port>}
image=${2:?image with pinned tag, e.g. vendor/app:1.2.3}
port=${3:?port the app listens on inside the container}

[[ $name =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "name must be lowercase letters, digits, dashes"; exit 1; }
[[ $image == *:* && $image != *:latest ]] || { echo "pin a version tag (no :latest)"; exit 1; }
[ ! -e "stacks/$name" ] || { echo "stacks/$name already exists"; exit 1; }

mkdir -p "stacks/$name"
cat > "stacks/$name/compose.yml" <<EOF
# ${name}. Data: ZFS tank/appdata/${name} (virtiofs -> /srv/appdata/${name}).
name: ${name}

services:
  ${name}:
    image: ${image}
    container_name: ${name}
    env_file: .env
    volumes:
      - /srv/appdata/${name}:/data
    networks: [proxy]
    labels:
      traefik.enable: "true"
      traefik.http.routers.${name}.rule: Host(\`${name}.\${LOCAL_DOMAIN}\`)
      traefik.http.services.${name}.loadbalancer.server.port: "${port}"
    security_opt:
      - no-new-privileges:true
    restart: unless-stopped

networks:
  proxy:
    external: true
EOF

cat > "roles/stacks/templates/${name}.env.j2" <<'EOF'
# {{ ansible_managed }}
TZ={{ homelab_timezone }}
LOCAL_DOMAIN={{ local_domain }}
# Secrets: add them with `sops secrets/homelab.sops.yml`, then reference them here, e.g.
# APP_SECRET={{ myapp_secret }}
EOF

cat <<EOF
Created stacks/${name}/compose.yml and roles/stacks/templates/${name}.env.j2.
Next:
  1. Adjust the volume path inside the container and anything else the app needs.
  2. Secrets: sops secrets/homelab.sops.yml  (then reference them in the .env.j2)
  3. Add "${name}" to stacks_enabled in inventories/homelab/group_vars/docker_hosts.yml
  4. make homelab-lint && ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i inventories/homelab homelab.yml --tags apps
  -> https://${name}.<local domain> (via Traefik)
EOF
