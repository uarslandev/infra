# ==============================================================================
# Developer Makefile - Automation Shortcuts
# ==============================================================================

.DEFAULT_GOAL := help
.PHONY: help apply dotfiles check lint sync test homelab homelab-check tf-plan tf-apply homelab-lint new-stack

help:
	@echo "Infrastructure & Dotfiles Automation"
	@echo ""
	@echo "Usage:"
	@echo "  make apply      Run full setup across current OS"
	@echo "  make dotfiles   Fast sync: apply dotfiles only via Chezmoi"
	@echo "  make check      Perform a dry-run check without applying changes"
	@echo "  make lint       Verify playbook syntax and run ansible-lint"
	@echo "  make sync       Audit package drift via pkgSync (Arch Linux)"
	@echo ""
	@echo "Homelab (run from WSL/Linux with the age key in ~/.config/sops/age/keys.txt):"
	@echo "  make tf-plan        Terraform plan (Proxmox VMs/LXCs)"
	@echo "  make tf-apply       Apply the last saved plan"
	@echo "  make homelab-check  Ansible dry run with diff"
	@echo "  make homelab        Apply homelab.yml"
	@echo "  make homelab-lint   Lint + validate homelab code"
	@echo "  make new-stack NAME=app IMAGE=vendor/app:1.2.3 PORT=8080   Scaffold a new stack"

apply:
	./bin/dotfiles

dotfiles:
	./bin/dotfiles --tags dotfiles

check:
	ansible-playbook main.yml --check

lint:
	ansible-playbook main.yml --syntax-check
	ansible-lint main.yml

sync:
	ansible-playbook sync.yml

# ------------------------------------------------------------------------------
# Homelab
# ------------------------------------------------------------------------------
HOMELAB_ANSIBLE = ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i inventories/homelab homelab.yml
TF = cd terraform/proxmox && sops exec-env secrets.sops.env

homelab:
	$(HOMELAB_ANSIBLE)

homelab-check:
	$(HOMELAB_ANSIBLE) --check --diff

tf-plan:
	$(TF) 'terraform plan -out=tfplan.tfplan'

tf-apply:
	$(TF) 'terraform apply tfplan.tfplan'

homelab-lint:
	ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i inventories/homelab homelab.yml --syntax-check
	ANSIBLE_CONFIG=ansible.cfg ansible-lint --profile production homelab.yml playbooks/homelab
	terraform -chdir=terraform/proxmox fmt -check -recursive
	terraform -chdir=terraform/proxmox validate
	scripts/homelab/check-secrets.sh

new-stack:
	scripts/homelab/new-stack.sh $(NAME) $(IMAGE) $(PORT)
