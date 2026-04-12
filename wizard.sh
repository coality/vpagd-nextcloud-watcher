#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

echo "=========================================="
echo "vpagd-nextcloud-watcher Setup Wizard"
echo "=========================================="
echo ""

whiptail --title "vpagd-nextcloud-watcher" --msgbox "Welcome to the vpagd-nextcloud-watcher setup wizard.\n\nThis wizard will help you configure and install everything.\n\nPress Enter to continue." 12 60 2>&1 || true

if ! whiptail --title "Prerequisites" --yesno "Do you want to check prerequisites now?" 8 50 2>&1; then
    echo "[SKIP] Skipping prerequisite check."
else
    echo "[INFO] Checking prerequisites..."
    MISSING_PKGS=""
    if ! command -v inotifywait &>/dev/null; then
        MISSING_PKGS="${MISSING_PKGS}inotify-tools "
    fi
    if ! command -v git &>/dev/null; then
        MISSING_PKGS="${MISSING_PKGS}git "
    fi

    if [[ -n "$MISSING_PKGS" ]]; then
        echo "[WARN] Missing packages: $MISSING_PKGS"
        if whiptail --title "Missing Packages" --yesno "Missing packages: ${MISSING_PKGS}\n\nDo you want to install them now? (requires sudo)" 10 50 2>&1; then
            echo "[INFO] Installing $MISSING_PKGS..."
            sudo apt-get update && sudo apt-get install -y $MISSING_PKGS 2>&1 | tail -5
            echo "[OK] Packages installed."
        fi
    else
        echo "[OK] All prerequisites are installed."
    fi
fi

VPAGD2ODT_BIN=""
VPAGD2ODT_INSTALLED=false

if command -v vpagd2odt &>/dev/null; then
    VPAGD2ODT_BIN=$(command -v vpagd2odt)
    VPAGD2ODT_INSTALLED=true
    echo "[OK] Found vpagd2odt at: $VPAGD2ODT_BIN"
else
    INSTALL_VPAGD=false
    if whiptail --title "vpagd2odt" --yesno "vpagd2odt not found.\n\nDo you want to install it automatically?" 10 50 2>&1; then
        INSTALL_VPAGD=true
        INSTALL_DIR=$(whiptail --title "Installation Directory" --inputbox "Enter installation directory for vpagd2odt:" 10 60 "/opt/vpagd2odt" 3>&1 1>&2 2>&3)
        if [[ -z "$INSTALL_DIR" ]]; then
            INSTALL_DIR="/opt/vpagd2odt"
        fi
        echo "[INFO] Installation directory: $INSTALL_DIR"

        VPAGD_INSTALL_METHOD=$(whiptail --title "Installation Method" --menu "How do you want to install vpagd2odt?" 12 50 3 \
            "script" "Use install script (auto-detect best method)" \
            "clone" "Git clone and build from source" \
            "manual" "I will install it manually" 3>&1 1>&2 2>&3) || VPAGD_INSTALL_METHOD="manual"

        mkdir -p "$INSTALL_DIR"

        if [[ "$VPAGD_INSTALL_METHOD" == "script" ]]; then
            echo "[INFO] Installing vpagd2odt via script..."
            cd "$PROJECT_DIR"
            if bash ./install_vpagd2odt.sh --dir "$INSTALL_DIR" 2>&1; then
                VPAGD2ODT_BIN="${INSTALL_DIR}/vpagd2odt"
                VPAGD2ODT_INSTALLED=true
                echo "[OK] vpagd2odt installed to ${VPAGD2ODT_BIN}"
            else
                echo "[ERROR] Failed to install vpagd2odt via script."
            fi
        elif [[ "$VPAGD_INSTALL_METHOD" == "clone" ]]; then
            if ! command -v git &>/dev/null; then
                echo "[ERROR] git is not installed."
            else
                echo "[INFO] Git clone method selected."
                VPAGD2ODT_TEMP=$(whiptail --title "Cloning vpagd2odt" --inputbox "Enter a temporary directory to clone into:" 10 60 "/tmp/vpagd2odt" 3>&1 1>&2 2>&3)
                if [[ -n "$VPAGD2ODT_TEMP" ]]; then
                    echo "[INFO] Cloning to ${VPAGD2ODT_TEMP}..."
                    rm -rf "$VPAGD2ODT_TEMP"
                    CLONE_OUTPUT=$(git clone https://github.com/coality/vpagd2odt.git "$VPAGD2ODT_TEMP" 2>&1)
                    CLONE_EXIT=$?
                    if [[ $CLONE_EXIT -ne 0 ]]; then
                        echo "[ERROR] Git clone failed:"
                        echo "$CLONE_OUTPUT"
                    elif [[ -d "$VPAGD2ODT_TEMP" ]]; then
                        cd "$VPAGD2ODT_TEMP"
                        echo "[INFO] Contents of cloned repo:"
                        ls -la
                        BUILD_OUTPUT=""
                        echo "[INFO] Building..."
                        if [[ -f "build.sh" ]]; then
                            echo "[INFO] Found build.sh, running..."
                            chmod +x build.sh
                            BUILD_OUTPUT=$(./build.sh 2>&1)
                            BUILD_EXIT=$?
                            echo "[DEBUG] build.sh exit code: $BUILD_EXIT"
                            if [[ -f "dist/vpagd2odt/vpagd2odt" ]]; then
                                mkdir -p "${INSTALL_DIR}"
                                cp dist/vpagd2odt/vpagd2odt "${INSTALL_DIR}/vpagd2odt"
                                chmod +x "${INSTALL_DIR}/vpagd2odt"
                                VPAGD2ODT_BIN="${INSTALL_DIR}/vpagd2odt"
                                VPAGD2ODT_INSTALLED=true
                                echo "[OK] vpagd2odt installed to ${VPAGD2ODT_BIN}"
                            else
                                echo "[ERROR] build.sh ran but binary not found in dist/vpagd2odt/"
                                echo "$BUILD_OUTPUT"
                            fi
                        elif [[ -f "pyproject.toml" ]]; then
                            echo "[INFO] Found pyproject.toml, installing via pip..."
                            BUILD_OUTPUT=$(pip install -e . 2>&1)
                            BUILD_EXIT=$?
                            echo "[DEBUG] pip install exit code: $BUILD_EXIT"
                            if command -v vpagd2odt &>/dev/null; then
                                VPAGD2ODT_BIN=$(command -v vpagd2odt)
                                VPAGD2ODT_INSTALLED=true
                                echo "[OK] vpagd2odt installed via pip: ${VPAGD2ODT_BIN}"
                            else
                                echo "[ERROR] pip install succeeded but vpagd2odt command not found in PATH"
                                echo "$BUILD_OUTPUT"
                            fi
                        elif [[ -f "Makefile" ]]; then
                            echo "[INFO] Found Makefile, running make..."
                            BUILD_OUTPUT=$(make 2>&1)
                            BUILD_EXIT=$?
                            echo "[DEBUG] Make exit code: $BUILD_EXIT"
                            if [[ -f "vpagd2odt" ]]; then
                                mkdir -p "${INSTALL_DIR}"
                                cp vpagd2odt "${INSTALL_DIR}/vpagd2odt"
                                chmod +x "${INSTALL_DIR}/vpagd2odt"
                                VPAGD2ODT_BIN="${INSTALL_DIR}/vpagd2odt"
                                VPAGD2ODT_INSTALLED=true
                                echo "[OK] vpagd2odt installed to ${VPAGD2ODT_BIN}"
                            fi
                        elif [[ -f "go.mod" ]]; then
                            echo "[INFO] Found go.mod, running go build..."
                            BUILD_OUTPUT=$(go build -o vpagd2odt 2>&1)
                            BUILD_EXIT=$?
                            echo "[DEBUG] Go build exit code: $BUILD_EXIT"
                            if [[ -f "vpagd2odt" ]]; then
                                mkdir -p "${INSTALL_DIR}"
                                cp vpagd2odt "${INSTALL_DIR}/vpagd2odt"
                                chmod +x "${INSTALL_DIR}/vpagd2odt"
                                VPAGD2ODT_BIN="${INSTALL_DIR}/vpagd2odt"
                                VPAGD2ODT_INSTALLED=true
                                echo "[OK] vpagd2odt installed to ${VPAGD2ODT_BIN}"
                            fi
                        else
                            echo "[WARN] No build system found."
                            echo "[INFO] Available files: $(ls -1)"
                            BUILD_OUTPUT="No build system found"
                        fi
                        cd "$PROJECT_DIR"
                        rm -rf "$VPAGD2ODT_TEMP"
                    fi
                fi
            fi
            if [[ "$VPAGD2ODT_INSTALLED" != "true" ]]; then
                echo "[ERROR] Failed to install vpagd2odt."
                echo "[INFO] Please install vpagd2odt manually or choose a different method."
                if whiptail --title "vpagd2odt Installation" --yesno "Installation failed.\n\nDo you want to enter the path manually?" 10 50 2>&1; then
                    VPAGD2ODT_BIN=$(whiptail --title "vpagd2odt Binary" --inputbox "Enter the full path to the vpagd2odt binary:" 10 60 "/opt/vpagd2odt/vpagd2odt" 3>&1 1>&2 2>&3)
                else
                    echo "[ERROR] Cannot continue without vpagd2odt."
                    exit 1
                fi
            fi
        fi
    fi
fi

echo ""
echo "[INFO] Now asking for configuration..."

SOURCE_DIR=$(whiptail --title "Source Directory" --inputbox "Enter the Nextcloud directory to watch for .vpagd files:\n\nExample: /var/www/nextcloud/data/user/files/vpagd" 12 70 "/var/www/nextcloud/data/user/files/vpagd" 3>&1 1>&2 2>&3)
if [[ -z "$SOURCE_DIR" ]]; then
    echo "[ERROR] Source directory cannot be empty."
    exit 1
fi

TARGET_DIR=$(whiptail --title "Target Directory" --inputbox "Enter the directory where .odt files will be written:\n\nExample: /var/www/nextcloud/data/user/files/odt" 12 70 "/var/www/nextcloud/data/user/files/odt" 3>&1 1>&2 2>&3)
if [[ -z "$TARGET_DIR" ]]; then
    echo "[ERROR] Target directory cannot be empty."
    exit 1
fi

if [[ -z "$VPAGD2ODT_BIN" ]]; then
    VPAGD2ODT_BIN=$(whiptail --title "vpagd2odt Binary" --inputbox "Enter the full path to the vpagd2odt binary:" 10 60 "/opt/vpagd2odt/vpagd2odt" 3>&1 1>&2 2>&3)
fi

LOG_FILE=$(whiptail --title "Log File" --inputbox "Enter the log file path:" 10 60 "$HOME/vpagd-nextcloud-watcher/vpagd-watcher.log" 3>&1 1>&2 2>&3)
if [[ -z "$LOG_FILE" ]]; then
    LOG_FILE="$HOME/vpagd-nextcloud-watcher/vpagd-watcher.log"
fi

LOG_LEVEL=$(whiptail --title "Log Level" --menu "Select log level:" 12 40 4 \
    "INFO" "Normal information (recommended)" \
    "DEBUG" "Detailed debug information" \
    "WARN" "Warnings and errors only" \
    "ERROR" "Errors only" 3>&1 1>&2 2>&3) || LOG_LEVEL="INFO"

LOCALE=$(whiptail --title "Output Locale" --menu "Select output filename locale:" 12 40 2 \
    "fr" "French (e.g., Messe du dimanche 08 Mars 2026.odt)" \
    "en" "English (e.g., Sunday Mass 08 March 2026.odt)" 3>&1 1>&2 2>&3) || LOCALE="fr"

NEXTCLOUD_SETUP=false
NEXTCLOUD_OCC=""
NEXTCLOUD_USER=""

if whiptail --title "Nextcloud Integration" --yesno "Do you want to configure Nextcloud integration?\n\nThis will run 'occ files:scan' after each conversion." 10 60 2>&1; then
    NEXTCLOUD_SETUP=true
    NEXTCLOUD_OCC=$(whiptail --title "Nextcloud OCC" --inputbox "Enter the path to Nextcloud occ:\n\nExample: /var/www/nextcloud/occ" 10 60 "/var/www/nextcloud/occ" 3>&1 1>&2 2>&3)
    NEXTCLOUD_USER=$(whiptail --title "Nextcloud User" --inputbox "Enter the Nextcloud username:" 10 50 "" 3>&1 1>&2 2>&3)
fi

echo "[INFO] Creating directories..."
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$SOURCE_DIR")"
mkdir -p "$(dirname "$TARGET_DIR")"
mkdir -p "$(dirname "$VPAGD2ODT_BIN" 2>/dev/null || echo "$HOME/bin")"

echo "[INFO] Writing config file..."
CONFIG_FILE="$PROJECT_DIR/config/vpagd-nextcloud-watcher.conf"

cat > "$CONFIG_FILE" << EOF
SOURCE_DIR="$SOURCE_DIR"
TARGET_DIR="$TARGET_DIR"
VPAGD2ODT_BIN="$VPAGD2ODT_BIN"
LOG_FILE="$LOG_FILE"
LOG_LEVEL="$LOG_LEVEL"
LOCALE="$LOCALE"
EOF

if [[ "$NEXTCLOUD_SETUP" == "true" && -n "$NEXTCLOUD_OCC" ]]; then
    echo "NEXTCLOUD_OCC=\"$NEXTCLOUD_OCC\"" >> "$CONFIG_FILE"
    echo "NEXTCLOUD_USER=\"$NEXTCLOUD_USER\"" >> "$CONFIG_FILE"
fi

chmod +x "$PROJECT_DIR/watch_vpagd.sh"

SERVICE_TYPE=$(whiptail --title "Service Installation" --menu "How do you want to install the systemd service?" 12 50 3 \
    "user" "User service (no root required, recommended)" \
    "system" "System service (requires root)" \
    "none" "Skip service installation" 3>&1 1>&2 2>&3) || SERVICE_TYPE="none"

if [[ "$SERVICE_TYPE" != "none" ]]; then
    SERVICE_FILE="$PROJECT_DIR/systemd/vpagd-nextcloud-watcher.service"

    if [[ "$SERVICE_TYPE" == "system" ]]; then
        SERVICE_DEST="/etc/systemd/system/vpagd-nextcloud-watcher.service"
        echo "[INFO] Installing system service to $SERVICE_DEST..."
        if sudo cp "$SERVICE_FILE" "$SERVICE_DEST" 2>&1; then
            sudo systemctl daemon-reload 2>&1
            if whiptail --title "Enable Service" --yesno "Enable and start the service now?" 8 40 2>&1; then
                echo "[INFO] Enabling and starting service..."
                sudo systemctl enable --now vpagd-nextcloud-watcher 2>&1
                echo "[OK] Service started."
            fi
        else
            echo "[ERROR] Failed to install system service."
        fi
    else
        USER_SERVICE_DIR="$HOME/.config/systemd/user"
        SERVICE_DEST="$USER_SERVICE_DIR/vpagd-nextcloud-watcher.service"
        echo "[INFO] Installing user service to $SERVICE_DEST..."
        mkdir -p "$USER_SERVICE_DIR"
        cp "$SERVICE_FILE" "$SERVICE_DEST"

        if command -v loginctl &>/dev/null; then
            if ! loginctl show-user "$USER" 2>/dev/null | grep -q "Linger"; then
                if whiptail --title "Enable Linger" --yesno "Enable linger for user $USER?\n\nThis allows user services to start at boot.\n\nRequires root." 10 60 2>&1; then
                    echo "[INFO] Enabling linger..."
                    sudo loginctl enable-linger "$USER" 2>&1
                fi
            fi
        fi

        echo "[INFO] Reloading systemd user daemon..."
        systemctl --user daemon-reload 2>&1
        if whiptail --title "Start Service" --yesno "Enable and start the service now?" 8 40 2>&1; then
            echo "[INFO] Enabling and starting service..."
            systemctl --user enable --now vpagd-nextcloud-watcher 2>&1
            echo "[OK] Service started."
        fi
    fi
fi

echo ""
echo "=========================================="
echo "Setup complete!"
echo "=========================================="
echo "Config file: $CONFIG_FILE"
echo "Source dir: $SOURCE_DIR"
echo "Target dir: $TARGET_DIR"
echo "Log file: $LOG_FILE"
echo "Locale: $LOCALE"
if [[ "$NEXTCLOUD_SETUP" == "true" ]]; then
    echo "Nextcloud: $NEXTCLOUD_USER"
fi
echo ""

whiptail --title "Setup Complete" --msgbox "Setup complete!\n\nConfig: $CONFIG_FILE\n\nCheck logs for details." 12 60 2>&1 || true
