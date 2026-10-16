#!/usr/bin/env bash
# Encrypted copy of the local Terraform state in git (SOPS + age, encrypted as one opaque blob,
# so not even resource names or IPs are readable in the public repo).
#   scripts/homelab/tfstate.sh backup  [root]   # terraform.tfstate -> terraform.tfstate.sops (run after every apply)
#   scripts/homelab/tfstate.sh restore [root]   # terraform.tfstate.sops -> terraform.tfstate (new machine)
#   scripts/homelab/tfstate.sh check   [root]   # is the encrypted copy up to date?
# root: the Terraform root under terraform/ (proxmox or cloudflare), default proxmox.
set -euo pipefail
root=${2:-proxmox}
[[ $root =~ ^[a-z]+$ ]] || { echo "root must be a directory name under terraform/"; exit 2; }
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)/terraform/$root"

state=terraform.tfstate
enc=terraform.tfstate.sops
decrypt() { sops decrypt --input-type binary --output-type binary "$enc"; }

case ${1:-} in
  backup)
    [[ -f $state ]] || { echo "no $state here, nothing to back up"; exit 1; }
    if [[ -f $enc ]] && cmp -s <(decrypt) "$state"; then
      echo "$enc is already up to date"; exit 0
    fi
    sops encrypt --input-type binary --output-type binary --filename-override "$enc" "$state" > "$enc.tmp"
    mv "$enc.tmp" "$enc"
    echo "updated $enc (serial $(python3 -c 'import json; print(json.load(open("terraform.tfstate"))["serial"])')); commit it"
    ;;
  restore)
    [[ -f $enc ]] || { echo "no $enc in the repo"; exit 1; }
    if [[ -f $state ]] && ! cmp -s <(decrypt) "$state"; then
      echo "$state exists and differs from the encrypted copy; refusing to overwrite (move it away first)"; exit 1
    fi
    umask 077
    decrypt > "$state"
    echo "restored $state (serial $(python3 -c 'import json; print(json.load(open("terraform.tfstate"))["serial"])'))"
    ;;
  check)
    if [[ -f $enc && -f $state ]] && cmp -s <(decrypt) "$state"; then
      echo "encrypted state copy is up to date"
    else
      echo "encrypted state copy is MISSING or OUTDATED: run scripts/homelab/tfstate.sh backup $root"; exit 1
    fi
    ;;
  *) echo "usage: $0 backup|restore|check [proxmox|cloudflare]"; exit 2 ;;
esac
