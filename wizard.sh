#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

whiptail --title "vpagd-nextcloud-watcher" --msgbox "Welcome to the vpagd-nextcloud-watcher setup wizard.\n\nThis wizard will help you configure and install everything.\n\nPress Enter to continue." 12 60 2>&1 || true

if ! whiptail --title "Prerequisites" --yesno "Do you want to check prerequisites now?" 8 50 2>&1; then
    echo "Skipping prerequisite check."
else
    MISSING_PKGS=""
    if ! command -v inotifywait &>/dev/null; then
        MISSING_PKGS="${MISSING_PKGS}inotify-tools "
    fi
    if ! command -v git &>/dev/null; then
        MISSING_PKGS="${MISSING_PKGS}git "
    fi

    if [[ -n "$MISSING_PKGS" ]]; then
        if whiptail --title "Missing Packages" --yesno "Missing packages: ${MISSING_PKGS}\n\nDo you want to install them now? (requires sudo)" 10 50 2>&1; then
            sudo apt-get update && sudo apt-get install -y $MISSING_PKGS 2>&1 | tail -5
        fi
    else
        whiptail --title "Prerequisites" --msgbox "All prerequisites are installed." 8 40 2>&1 || true
    fi
fi

VPAGD2ODT_BIN=""
VPAGD2ODT_INSTALLED=false

if command -v vpagd2odt &>/dev/null; then
    VPAGD2ODT_BIN=$(command -v vpagd2odt)
    VPAGD2ODT_INSTALLED=true
    whiptail --title "vpagd2odt" --msgbox "Found vpagd2odt at: $VPAGD2ODT_BIN" 8 50 2>&1 || true
else
    INSTALL_VPAGD=false
    if whiptail --title "vpagd2odt" --yesno "vpagd2odt not found.\n\nDo you want to install it automatically?" 10 50 2>&1; then
        INSTALL_VPAGD=true
        INSTALL_DIR=$(whiptail --title "Installation Directory" --inputbox "Enter installation directory for vpagd2odt:" 10 60 "$HOME/bin" 3>&1 1>&2 2>&3)
        if [[ -z "$INSTALL_DIR" ]]; then
            INSTALL_DIR="$HOME/bin"
        fi
        whiptail --title "Installing vpagd2odt" --msgbox "Installing vpagd2odt to ${INSTALL_DIR}..." 8 50 2>&1 || true

        mkdir -p "$INSTALL_DIR"
        cd "$PROJECT_DIR"
        if bash ./install_vpagd2odt.sh --dir "$INSTALL_DIR"; then
            VPAGD2ODT_BIN="${INSTALL_DIR}/vpagd2odt"
            VPAGD2ODT_INSTALLED=true
            whiptail --title "Success" --msgbox "vpagd2odt installed successfully!" 8 40 2>&1 || true
        else
            whiptail --title "Error" --msgbox "Failed to install vpagd2odt.\n\nPlease install it manually." 10 50 2>&1 || true
        fi
    fi
fi

SOURCE_DIR=$(whiptail --title "Source Directory" --inputbox "Enter the Nextcloud directory to watch for .vpagd files:\n\nExample: /var/www/nextcloud/data/user/files/vpagd" 12 70 "/var/www/nextcloud/data/user/files/vpagd" 3>&1 1>&2 2>&3)
if [[ -z "$SOURCE_DIR" ]]; then
    whiptail --title "Error" --msgbox "Source directory cannot be empty." 8 40 2>&1 || true
    exit 1
fi

TARGET_DIR=$(whiptail --title "Target Directory" --inputbox "Enter the directory where .odt files will be written:\n\nExample: /var/www/nextcloud/data/user/files/odt" 12 70 "/var/www/nextcloud/data/user/files/odt" 3>&1 1>&2 2>&3)
if [[ -z "$TARGET_DIR" ]]; then
    whiptail --title "Error" --msgbox "Target directory cannot be empty." 8 40 2>&1 || true
    exit 1
fi

if [[ -z "$VPAGD2ODT_BIN" ]]; then
    VPAGD2ODT_BIN=$(whiptail --title "vpagd2odt Binary" --inputbox "Enter the full path to the vpagd2odt binary:" 10 60 "/home/$USER/bin/vpagd2odt" 3>&1 1>&2 2>&3)
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

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$SOURCE_DIR")"
mkdir -p "$(dirname "$TARGET_DIR")"
mkdir -p "$(dirname "$VPAGD2ODT_BIN" 2>/dev/null || echo "$HOME/bin")"

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
        if whiptail --title "Install Service" --yesno "Install system service to $SERVICE_DEST?\n\nRequires root password." 10 50 2>&1; then
            sudo cp "$SERVICE_FILE" "$SERVICE_DEST"
            sudo systemctl daemon-reload
            if whiptail --title "Enable Service" --yesno "Enable and start the service now?" 8 40 2>&1; then
                sudo systemctl enable --now vpagd-nextcloud-watcher
                whiptail --title "Service Started" --msgbox "Service enabled and started." 8 40 2>&1 || true
            fi
        fi
    else
        USER_SERVICE_DIR="$HOME/.config/systemd/user"
        SERVICE_DEST="$USER_SERVICE_DIR/vpagd-nextcloud-watcher.service"
        mkdir -p "$USER_SERVICE_DIR"
        cp "$SERVICE_FILE" "$SERVICE_DEST"

        if command -v loginctl &>/dev/null; then
            if ! loginctl show-user "$USER" 2>/dev/null | grep -q "Linger"; then
                if whiptail --title "Enable Linger" --yesno "Enable linger for user $USER?\n\nThis allows user services to start at boot.\n\nRequires root." 10 60 2>&1; then
                    sudo loginctl enable-linger "$USER"
                fi
            fi
        fi

        systemctl --user daemon-reload
        if whiptail --title "Start Service" --yesno "Enable and start the service now?" 8 40 2>&1; then
            systemctl --user enable --now vpagd-nextcloud-watcher
            whiptail --title "Service Started" --msgbox "Service enabled and started." 8 40 2>&1 || true
        fi
    fi
fi

SUMMARY="Setup complete!\n\n"
SUMMARY+="Config file: $CONFIG_FILE\n"
SUMMARY+="Source dir: $SOURCE_DIR\n"
SUMMARY+="Target dir: $TARGET_DIR\n"
SUMMARY+="Log file: $LOG_FILE\n"
SUMMARY+="Locale: $LOCALE\n"
if [[ "$NEXTCLOUD_SETUP" == "true" ]]; then
    SUMMARY+="Nextcloud: $NEXTCLOUD_USER\n"
fi

whiptail --title "Setup Complete" --msgbox "$SUMMARY" 15 60 2>&1 || true
