#!/bin/bash
# =============================================================================
# Script : Configuration des clés SSH pour Ansible
# Usage  : bash setup-ssh.sh
# Cibles : 192.168.43.133 (Harbor, lms) + 192.168.43.109 (K8s, lms)
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✅]${NC} $1"; }
info() { echo -e "${CYAN}[ℹ️ ]${NC} $1"; }
warn() { echo -e "${YELLOW}[⚠️ ]${NC} $1"; }

HARBOR_IP="192.168.43.133"
K8S_IP="192.168.43.129"
SSH_USER="lms"
KEY_PATH="$HOME/.ssh/id_rsa"

# ── Générer la clé SSH si elle n'existe pas ───────────────────────────────────
if [ ! -f "${KEY_PATH}" ]; then
    info "Génération de la clé SSH..."
    ssh-keygen -t rsa -b 4096 -f "${KEY_PATH}" -N "" -C "ansible-cicd"
    log "Clé SSH générée : ${KEY_PATH}"
else
    warn "Clé SSH déjà existante : ${KEY_PATH}"
fi

# ── Copier la clé vers Harbor VM ──────────────────────────────────────────────
info "Copie de la clé SSH vers Harbor VM (${SSH_USER}@${HARBOR_IP})..."
ssh-copy-id -i "${KEY_PATH}.pub" -o StrictHostKeyChecking=no "${SSH_USER}@${HARBOR_IP}"
log "Clé SSH copiée vers Harbor VM"

# ── Copier la clé vers Kubernetes VM ─────────────────────────────────────────
info "Copie de la clé SSH vers Kubernetes VM (${SSH_USER}@${K8S_IP})..."
ssh-copy-id -i "${KEY_PATH}.pub" -o StrictHostKeyChecking=no "${SSH_USER}@${K8S_IP}"
log "Clé SSH copiée vers Kubernetes VM"

# ── Tester la connexion ───────────────────────────────────────────────────────
info "Test connexion Harbor VM..."
ssh -o StrictHostKeyChecking=no "${SSH_USER}@${HARBOR_IP}" "echo '✅ Harbor VM accessible'" && \
    log "Connexion Harbor OK" || warn "❌ Connexion Harbor échouée"

info "Test connexion Kubernetes VM..."
ssh -o StrictHostKeyChecking=no "${SSH_USER}@${K8S_IP}" "echo '✅ Kubernetes VM accessible'" && \
    log "Connexion K8s OK" || warn "❌ Connexion K8s échouée"

# ── Test Ansible ping ─────────────────────────────────────────────────────────
info "Test Ansible ping sur tous les hôtes..."
cd "$(dirname "${BASH_SOURCE[0]}")/../ansible"
ansible all -i inventory/hosts.yml -m ping

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ✅ SSH configuré pour Ansible !"
echo -e "  Harbor VM  : ${SSH_USER}@${HARBOR_IP} → OK"
echo -e "  K8s VM     : ${SSH_USER}@${K8S_IP} → OK"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
