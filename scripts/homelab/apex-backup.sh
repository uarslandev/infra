#!/usr/bin/env bash
# A consistent backup of the APEX sync server, before any upgrade that changes its database.
#   scripts/homelab/apex-backup.sh            (or: make apex-backup)
# Stops PocketBase for a few seconds (a running SQLite file is not a safe copy), archives
# /srv/apex/pb_data to /var/backups/apex/pb_data-<UTC time>.tar.gz on the apps VM (root-only),
# and always starts it again, also when the archive fails. Prints the file and its size.
# Nothing leaves the VM: the archive sits next to the ZFS snapshots of tank/apex.
set -euo pipefail
host=${APEX_BACKUP_HOST:-apps}

# -t: sudo on the VM may ask for the password. The remote script is quoted, so nothing in it
# is expanded here on the admin PC.
ssh -t "$host" 'bash -s' <<'REMOTE'
set -euo pipefail
dir=/var/backups/apex
file="$dir/pb_data-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
sudo install -d -m 0700 "$dir"
sudo docker stop apex-pocketbase >/dev/null
trap 'sudo docker start apex-pocketbase >/dev/null' EXIT
sudo tar -czf "$file" -C /srv/apex pb_data
sudo chmod 0600 "$file"
echo "backup: $file ($(sudo du -h "$file" | cut -f1))"
REMOTE
