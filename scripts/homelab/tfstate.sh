#!/usr/bin/env bash
# Encrypted copy of the local Terraform state in git (SOPS + age, encrypted as one opaque blob,
# so not even resource names or IPs are readable in the public repo).
#   scripts/homelab/tfstate.sh backup    # terraform.tfstate -> terraform.tfstate.sops (run after every apply)
#   scripts/homelab/tfstate.sh restore   # terraform.tfstate.sops -> terraform.tfstate (new machine)
#   scripts/homelab/tfstate.sh check     # is the encrypted copy up to date?
set -euo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)/terraform/proxmox"

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
      echo "encrypted state copy is MISSING or OUTDATED: run make tf-backup-state"; exit 1
    fi
    ;;
  *) echo "usage: $0 backup|restore|check"; exit 2 ;;
esac
