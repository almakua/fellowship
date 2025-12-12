#!/usr/bin/env bash
# =============================================================================
# Fellowship K3s Cluster - Setup Script
# =============================================================================
# Prepara l'ambiente locale per eseguire i playbook Ansible
# =============================================================================

set -euo pipefail

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzioni helper
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Banner
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           Fellowship - K3s Cluster Setup                  ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Directory del progetto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

info "Working directory: $PROJECT_DIR"

# =============================================================================
# 1. Verifica Python
# =============================================================================
info "Checking Python..."

if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    success "Python $PYTHON_VERSION found"
else
    error "Python 3 not found. Please install Python 3.10+"
fi

# =============================================================================
# 2. Crea Virtual Environment
# =============================================================================
info "Setting up Python virtual environment..."

if [ -d ".venv" ]; then
    warn "Virtual environment already exists, skipping creation"
else
    python3 -m venv .venv
    success "Virtual environment created"
fi

# Attiva venv
# shellcheck source=/dev/null
source .venv/bin/activate
success "Virtual environment activated"

# =============================================================================
# 3. Installa dipendenze Python
# =============================================================================
info "Installing Python dependencies..."

pip install --upgrade pip --quiet
pip install ansible kubernetes --quiet

ANSIBLE_VERSION=$(ansible --version | head -n1)
success "Installed: $ANSIBLE_VERSION"

# =============================================================================
# 4. Installa Ansible Collections
# =============================================================================
info "Installing Ansible collections..."

if [ -f "requirements.yml" ]; then
    ansible-galaxy collection install -r requirements.yml --force
    success "Ansible collections installed"
else
    warn "requirements.yml not found, skipping collections"
fi

# =============================================================================
# 5. Crea directory mancanti
# =============================================================================
info "Creating required directories..."

mkdir -p .ansible_cache
mkdir -p collections

success "Directories created"

# =============================================================================
# 6. Verifica inventory
# =============================================================================
info "Checking inventory configuration..."

if grep -q "192.168.1.X" inventory/hosts.yml 2>/dev/null; then
    warn "Inventory contains placeholder IPs (192.168.1.X)"
    warn "Please edit inventory/hosts.yml with real IPs"
else
    success "Inventory configured"
fi

# =============================================================================
# 7. Verifica secrets
# =============================================================================
info "Checking secrets configuration..."

if [ -f "vault/secrets.yml" ]; then
    if head -n1 vault/secrets.yml | grep -q '^\$ANSIBLE_VAULT'; then
        success "Secrets file exists and is encrypted"
    else
        warn "Secrets file exists but is NOT encrypted!"
        warn "Run: ansible-vault encrypt vault/secrets.yml"
    fi
else
    warn "Secrets file not found"
    warn "Copy vault/secrets.yml.example to vault/secrets.yml and configure it"
fi

# =============================================================================
# 8. Verifica SSH key
# =============================================================================
info "Checking SSH configuration..."

SSH_KEY="$HOME/.ssh/id_ed25519"
if [ -f "$SSH_KEY" ]; then
    success "SSH key found: $SSH_KEY"
else
    SSH_KEY="$HOME/.ssh/id_rsa"
    if [ -f "$SSH_KEY" ]; then
        success "SSH key found: $SSH_KEY"
        warn "Consider using Ed25519 keys for better security"
    else
        warn "No SSH key found in ~/.ssh/"
        warn "Generate one with: ssh-keygen -t ed25519"
    fi
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Setup Complete!                        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Next steps:"
echo ""
echo "  1. Edit inventory with real IPs:"
echo "     ${YELLOW}vim inventory/hosts.yml${NC}"
echo ""
echo "  2. Configure secrets:"
echo "     ${YELLOW}cp vault/secrets.yml.example vault/secrets.yml${NC}"
echo "     ${YELLOW}vim vault/secrets.yml${NC}"
echo "     ${YELLOW}ansible-vault encrypt vault/secrets.yml${NC}"
echo ""
echo "  3. Test connectivity:"
echo "     ${YELLOW}ansible all -m ping${NC}"
echo ""
echo "  4. Deploy the cluster:"
echo "     ${YELLOW}ansible-playbook playbooks/site.yml --ask-vault-pass${NC}"
echo ""
echo "For detailed instructions, see: ${BLUE}SETUP.md${NC}"
echo ""

