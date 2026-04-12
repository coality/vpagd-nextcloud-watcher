#!/bin/bash

set -euo pipefail

REPO_URL="https://github.com/coality/vpagd2odt"
INSTALL_DIR="${HOME}/bin"
BINARY_NAME="vpagd2odt"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Update vpagd2odt to the latest version from GitHub.

OPTIONS:
    -d, --dir PATH       Installation directory (default: ~/bin)
    -b, --bin NAME       Binary name (default: vpagd2odt)
    -c, --check          Check for updates without installing
    -h, --help           Show this help message

EXAMPLES:
    $0                              Update vpagd2odt to latest
    $0 -d /opt/bin                  Install to /opt/bin
    $0 -c                           Check if update available

EOF
}

check_requirements() {
    if ! command -v git &> /dev/null; then
        log_error "git is required but not installed"
        return 1
    fi

    if ! command -v go &> /dev/null && [[ ! -f "${INSTALL_DIR}/${BINARY_NAME}" ]]; then
        log_warn "go is not installed - cannot build from source"
        log_warn "Will try to download pre-built binary instead"
    fi

    return 0
}

get_current_version() {
    if [[ -f "${INSTALL_DIR}/${BINARY_NAME}" ]]; then
        "${INSTALL_DIR}/${BINARY_NAME}" --version 2>/dev/null || echo "unknown"
    else
        echo "not installed"
    fi
}

check_for_updates() {
    log_info "Checking for updates..."

    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" EXIT

    git clone --bare "$REPO_URL" "$temp_dir/repo.git" 2>/dev/null

    local latest_tag
    latest_tag=$(git -C "$temp_dir/repo.git" describe --tags --abbrev=0 2>/dev/null || echo "")

    if [[ -z "$latest_tag" ]]; then
        log_warn "Could not determine latest version from remote"
        log_info "Try running without --check to force update"
        return 1
    fi

    local current_version
    current_version=$(get_current_version)

    log_info "Current version: $current_version"
    log_info "Latest version:  $latest_tag"

    if [[ "$current_version" == "$latest_tag" ]]; then
        log_info "Already up to date"
        return 0
    else
        log_warn "Update available"
        return 1
    fi
}

download_release() {
    local version="$1"
    local os="$2"
    local arch="$3"
    local download_url="https://github.com/coality/vpagd2odt/releases/download/${version}/${BINARY_NAME}-${os}-${arch}"

    log_info "Downloading ${download_url}..."

    local temp_file
    temp_file=$(mktemp)

    if command -v curl &> /dev/null; then
        curl -sL "$download_url" -o "$temp_file"
    elif command -v wget &> /dev/null; then
        wget -q "$download_url" -O "$temp_file"
    else
        log_error "curl or wget is required to download binaries"
        return 1
    fi

    if [[ ! -s "$temp_file" ]]; then
        log_error "Download failed or file is empty"
        rm -f "$temp_file"
        return 1
    fi

    mkdir -p "${INSTALL_DIR}"
    mv "$temp_file" "${INSTALL_DIR}/${BINARY_NAME}"
    chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

    log_info "Installed ${BINARY_NAME} ${version} to ${INSTALL_DIR}"
}

build_from_source() {
    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" EXIT

    log_info "Cloning vpagd2odt repository..."
    git clone "$REPO_URL" "$temp_dir/vpagd2odt"

    cd "$temp_dir/vpagd2odt"

    if [[ -f "Makefile" ]]; then
        log_info "Building with Makefile..."
        make
    elif [[ -f "go.mod" ]]; then
        log_info "Building with Go..."
        go build -o "$BINARY_NAME"
    else
        log_error "Could not determine build system"
        return 1
    fi

    if [[ ! -f "$BINARY_NAME" ]]; then
        log_error "Build failed - binary not found"
        return 1
    fi

    mkdir -p "${INSTALL_DIR}"
    cp "$BINARY_NAME" "${INSTALL_DIR}/${BINARY_NAME}"
    chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

    log_info "Built and installed ${BINARY_NAME} to ${INSTALL_DIR}"
}

update_vpagd2odt() {
    log_info "Updating vpagd2odt..."

    if ! check_requirements; then
        return 1
    fi

    local os
    local arch
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)

    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l) arch="arm" ;;
    esac

    if command -v go &> /dev/null || [[ -f "${INSTALL_DIR}/${BINARY_NAME}" ]]; then
        build_from_source && return 0
    fi

    local latest_tag
    latest_tag=$(git ls-remote --tags "$REPO_URL" 2>/dev/null | grep -E 'refs/tags/v[0-9].*$' | grep -v '\^{}' | cut -d'/' -f3 | sed 's/^v//' | sort -V | tail -1)

    if [[ -n "$latest_tag" ]]; then
        download_release "v${latest_tag}" "$os" "$arch" && return 0
    fi

    log_error "Could not find a suitable update method"
    log_info "Please install manually: $REPO_URL"
    return 1
}

main() {
    if [[ $# -eq 0 ]]; then
        update_vpagd2odt
        return $?
    fi

    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--check)
            check_for_updates
            exit $?
            ;;
        -d|--dir)
            if [[ -z "${2:-}" ]]; then
                log_error "Option $1 requires an argument"
                exit 1
            fi
            INSTALL_DIR="$2"
            shift
            ;;
        -b|--bin)
            if [[ -z "${2:-}" ]]; then
                log_error "Option $1 requires an argument"
                exit 1
            fi
            BINARY_NAME="$2"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac

    update_vpagd2odt
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
