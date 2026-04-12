#!/bin/bash

set -e

REPO_URL="https://github.com/coality/vpagd2odt"
INSTALL_DIR="${HOME}/bin"
BINARY_NAME="vpagd2odt"

echo "=========================================="
echo "vpagd-nextcloud-watcher installer"
echo "=========================================="

if [[ -z "$1" || "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 [INSTALL_PATH]"
    echo ""
    echo "  INSTALL_PATH    Directory to install vpagd2odt binary (default: ~/bin)"
    echo ""
    echo "This script installs vpagd2odt from: $REPO_URL"
    echo ""
    echo "Prerequisites will be checked and reported."
    exit 0
fi

if [[ -n "$1" ]]; then
    INSTALL_DIR="$1"
fi

echo ""
echo "[1/5] Checking prerequisites..."

check_command() {
    if command -v "$1" &> /dev/null; then
        echo "  [OK] $1 is installed"
        return 0
    else
        echo "  [MISSING] $1 is NOT installed"
        return 1
    fi
}

MISSING=0
check_command "inotifywait" || MISSING=1
check_command "bash" || MISSING=1
check_command "date" || MISSING=1

if [[ "$MISSING" -eq 1 ]]; then
    echo ""
    echo "ERROR: Some prerequisites are missing. Please install them first."
    exit 1
fi

echo ""
echo "[2/5] Checking vpagd2odt installation..."

if command -v vpagd2odt &> /dev/null; then
    echo "  [OK] vpagd2odt is already in PATH"
    VPAGD2ODT_PATH=$(command -v vpagd2odt)
elif [[ -f "${INSTALL_DIR}/${BINARY_NAME}" ]]; then
    echo "  [OK] vpagd2odt found at ${INSTALL_DIR}/${BINARY_NAME}"
    VPAGD2ODT_PATH="${INSTALL_DIR}/${BINARY_NAME}"
else
    echo "  [WARNING] vpagd2odt not found"
    echo ""
    echo "  Please install vpagd2odt manually:"
    echo "    - From source: $REPO_URL"
    echo "    - Or download a release binary"
    echo "    - Then place it in: ${INSTALL_DIR}/${BINARY_NAME}"
    echo "    - Or add it to your PATH"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "[3/5] Creating directories..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "${SCRIPT_DIR}/config"
mkdir -p "${SCRIPT_DIR}/systemd"
mkdir -p "${INSTALL_DIR}"

echo ""
echo "[4/5] Checking project files..."

for file in "watch_vpagd.sh" "update_vpagd2odt.sh" "config/vpagd-nextcloud-watcher.conf.example" "systemd/vpagd-nextcloud-watcher.service"; do
    if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
        echo "  [OK] ${file}"
    else
        echo "  [MISSING] ${file}"
    fi
done

echo ""
echo "[5/5] Installation summary..."

echo "  Script directory: ${SCRIPT_DIR}"
echo "  vpagd2odt path: ${VPAGD2ODT_PATH:-not found}"
echo ""
echo "Next steps:"
echo "  1. Copy config file:"
echo "      cp ${SCRIPT_DIR}/config/vpagd-nextcloud-watcher.conf.example \\"
echo "         ${SCRIPT_DIR}/config/vpagd-nextcloud-watcher.conf"
echo ""
echo "  2. Edit configuration with your paths"
echo ""
echo "  3. Install systemd service (requires root):"
echo "      sudo cp ${SCRIPT_DIR}/systemd/vpagd-nextcloud-watcher.service \\"
echo "         /etc/systemd/system/"
echo "      sudo systemctl daemon-reload"
echo ""
echo "  4. Start and enable service (requires root):"
echo "      sudo systemctl enable --now vpagd-nextcloud-watcher"
echo ""
echo "=========================================="
echo "Installation check complete!"
echo "=========================================="
