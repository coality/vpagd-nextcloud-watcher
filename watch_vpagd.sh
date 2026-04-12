#!/bin/bash

set -euo pipefail

SOURCE_DIR=""
TARGET_DIR=""
VPAGD2ODT_BIN=""
LOG_FILE=""
LOG_LEVEL="INFO"
LOCALE="fr"
NEXTCLOUD_OCC=""
NEXTCLOUD_USER=""

declare -A FRENCH_MONTHS=(
    [01]="Janvier" [02]="Février" [03]="Mars" [04]="Avril"
    [05]="Mai" [06]="Juin" [07]="Juillet" [08]="Août"
    [09]="Septembre" [10]="Octobre" [11]="Novembre" [12]="Décembre"
)

declare -A ENGLISH_MONTHS=(
    [01]="January" [02]="February" [03]="March" [04]="April"
    [05]="May" [06]="June" [07]="July" [08]="August"
    [09]="September" [10]="October" [11]="November" [12]="December"
)

declare -A FRENCH_DAYS=(
    [0]="dimanche" [1]="lundi" [2]="mardi" [3]="mercredi"
    [4]="jeudi" [5]="vendredi" [6]="samedi"
)

declare -A ENGLISH_DAYS=(
    [0]="sunday" [1]="monday" [2]="tuesday" [3]="wednesday"
    [4]="thursday" [5]="friday" [6]="saturday"
)

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE" 2>/dev/null || echo "[${timestamp}] [${level}] ${message}"
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    log "WARN" "$@"
}

log_error() {
    log "ERROR" "$@"
}

log_debug() {
    if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
        log "DEBUG" "$@"
    fi
}

validate_config() {
    if [[ -z "$SOURCE_DIR" ]]; then
        log_error "SOURCE_DIR is not configured"
        return 1
    fi

    if [[ -z "$TARGET_DIR" ]]; then
        log_error "TARGET_DIR is not configured"
        return 1
    fi

    if [[ -z "$VPAGD2ODT_BIN" ]]; then
        log_error "VPAGD2ODT_BIN is not configured"
        return 1
    fi

    if [[ ! -d "$SOURCE_DIR" ]]; then
        log_error "SOURCE_DIR does not exist: $SOURCE_DIR"
        return 1
    fi

    if [[ ! -d "$TARGET_DIR" ]]; then
        log_error "TARGET_DIR does not exist: $TARGET_DIR"
        return 1
    fi

    if [[ ! -x "$VPAGD2ODT_BIN" ]]; then
        log_error "VPAGD2ODT_BIN is not executable or not found: $VPAGD2ODT_BIN"
        return 1
    fi

    if [[ "$LOCALE" != "fr" && "$LOCALE" != "en" ]]; then
        log_error "LOCALE must be 'fr' or 'en', got: $LOCALE"
        return 1
    fi

    return 0
}

validate_filename() {
    local filename="$1"

    if [[ ! "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
        log_debug "Filename does not match required format YYYY.MM.DD.vpagd: $filename"
        return 1
    fi

    local year="${filename:0:4}"
    local month="${filename:5:2}"
    local day="${filename:8:2}"

    if [[ "$month" -lt 01 || "$month" -gt 12 ]]; then
        log_warn "Invalid month in filename: $month (file: $filename)"
        return 1
    fi

    if [[ "$day" -lt 01 || "$day" -gt 31 ]]; then
        log_warn "Invalid day in filename: $day (file: $filename)"
        return 1
    fi

    return 0
}

extract_date_from_filename() {
    local filename="$1"

    if ! validate_filename "$filename"; then
        return 1
    fi

    local year="${filename:0:4}"
    local month="${filename:5:2}"
    local day="${filename:8:2}"

    echo "${year} ${month} ${day}"
}

convert_date_to_localized() {
    local year="$1"
    local month="$2"
    local day="$3"
    local locale="${4:-${LOCALE}}"

    local day_of_week
    day_of_week=$(date -d "${year}-${month}-${day}" '+%w' 2>/dev/null || echo "")
    if [[ -z "$day_of_week" ]]; then
        log_error "Invalid date: ${year}-${month}-${day}"
        return 1
    fi

    local month_name=""
    local day_name=""

    case "$locale" in
        fr)
            month_name="${FRENCH_MONTHS[$month]:-}"
            day_name="${FRENCH_DAYS[$day_of_week]:-}"
            if [[ -z "$month_name" ]]; then
                log_error "Unknown month number: $month"
                return 1
            fi
            if [[ -z "$day_name" ]]; then
                log_error "Unknown day of week: $day_of_week"
                return 1
            fi
            echo "Messe du ${day_name} ${day} ${month_name} ${year}.odt"
            ;;
        en)
            month_name="${ENGLISH_MONTHS[$month]:-}"
            day_name="${ENGLISH_DAYS[$day_of_week]:-}"
            if [[ -z "$month_name" ]]; then
                log_error "Unknown month number: $month"
                return 1
            fi
            if [[ -z "$day_name" ]]; then
                log_error "Unknown day of week: $day_of_week"
                return 1
            fi
            echo "${day_name^} Mass ${day} ${month_name} ${year}.odt"
            ;;
        *)
            log_error "Unsupported locale: $locale (supported: fr, en)"
            return 1
            ;;
    esac
}

convert_vpagd_to_odt() {
    local source_file="$1"
    local target_file="$2"

    log_info "Converting: $source_file -> $target_file"

    if ! "$VPAGD2ODT_BIN" "$source_file" "$target_file"; then
        log_error "Conversion failed for: $source_file"
        return 1
    fi

    log_info "Conversion successful: $target_file"
    return 0
}

scan_nextcloud() {
    local target_file="$1"
    local relative_path="${target_file#$TARGET_DIR/}"

    if [[ -z "$NEXTCLOUD_OCC" ]]; then
        log_debug "Nextcloud occ not configured, skipping scan"
        return 0
    fi

    if [[ -z "$NEXTCLOUD_USER" ]]; then
        log_warn "NEXTCLOUD_USER not configured, skipping Nextcloud scan"
        return 0
    fi

    log_info "Scanning Nextcloud for: $relative_path"

    if ! "$NEXTCLOUD_OCC" files:scan --path="$NEXTCLOUD_USER/files/$relative_path" 2>&1; then
        log_warn "Nextcloud scan failed for: $relative_path"
        return 1
    fi

    log_info "Nextcloud scan successful for: $relative_path"
    return 0
}

process_vpagd_file() {
    local full_path="$1"
    local filename
    filename=$(basename "$full_path")

    log_debug "Processing file: $full_path"

    if ! validate_filename "$filename"; then
        return 0
    fi

    local date_info
    date_info=$(extract_date_from_filename "$filename") || return 1

    read -r year month day <<< "$date_info"

    local output_filename
    output_filename=$(convert_date_to_localized "$year" "$month" "$day") || return 1

    local target_path="${TARGET_DIR}/${output_filename}"

    if ! convert_vpagd_to_odt "$full_path" "$target_path"; then
        return 1
    fi

    scan_nextcloud "$target_path"
}

run_watcher() {
    log_info "Starting vpagd-nextcloud-watcher"
    log_info "Source directory: $SOURCE_DIR"
    log_info "Target directory: $TARGET_DIR"
    log_info "Using vpagd2odt: $VPAGD2ODT_BIN"
    log_info "Locale: $LOCALE"
    log_info "Log file: $LOG_FILE"

    if [[ -n "$NEXTCLOUD_OCC" ]]; then
        log_info "Nextcloud occ: $NEXTCLOUD_OCC"
        log_info "Nextcloud user: $NEXTCLOUD_USER"
    else
        log_info "Nextcloud occ: not configured"
    fi

    inotifywait -m -r -e close_write -e moved_to \
        --format '%w%f' \
        --include '\.vpagd$' \
        "$SOURCE_DIR" 2>&1 | while read -r file_path; do

        log_debug "Event detected for: $file_path"

        if [[ -f "$file_path" ]]; then
            process_vpagd_file "$file_path"
        else
            log_debug "File no longer exists or is not accessible: $file_path"
        fi

    done
}

load_config() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        return 1
    fi

    log_debug "Loading config from: $config_file"

    while IFS='=' read -r key value; do
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"

        if [[ -z "$key" || "$key" =~ ^# ]]; then
            continue
        fi

        case "$key" in
            SOURCE_DIR)
                SOURCE_DIR="$value"
                ;;
            TARGET_DIR)
                TARGET_DIR="$value"
                ;;
            VPAGD2ODT_BIN)
                VPAGD2ODT_BIN="$value"
                ;;
            LOG_FILE)
                LOG_FILE="$value"
                ;;
            LOG_LEVEL)
                LOG_LEVEL="$value"
                ;;
            LOCALE)
                LOCALE="$value"
                ;;
            NEXTCLOUD_OCC)
                NEXTCLOUD_OCC="$value"
                ;;
            NEXTCLOUD_USER)
                NEXTCLOUD_USER="$value"
                ;;
            *)
                log_warn "Unknown config key: $key"
                ;;
        esac
    done < "$config_file"

    return 0
}

main() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    local config_file="${script_dir}/config/vpagd-nextcloud-watcher.conf"

    if [[ -n "${CONFIG_FILE:-}" ]]; then
        config_file="$CONFIG_FILE"
    fi

    if [[ $# -gt 0 && ( "$1" == "-c" || "$1" == "--config" ) ]]; then
        config_file="$2"
        shift 2
    fi

    if [[ $# -gt 0 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -c, --config FILE    Use alternate config file"
        echo "  -h, --help          Show this help message"
        echo ""
        echo "Environment variables:"
        echo "  CONFIG_FILE         Alternate config file path"
        echo ""
        echo "Config file: $config_file"
        exit 0
    fi

    if ! load_config "$config_file"; then
        log_error "Failed to load config from: $config_file"
        exit 1
    fi

    if [[ -z "$LOG_FILE" ]]; then
        LOG_FILE="${script_dir}/vpagd-watcher.log"
    fi

    if ! validate_config; then
        log_error "Configuration validation failed"
        exit 1
    fi

    log_info "Configuration loaded successfully"

    run_watcher
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
