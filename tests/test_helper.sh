#!/bin/bash

set -euo pipefail

export TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
export SRC_DIR="${TEST_DIR}/tmp/source"
export TARGET_DIR="${TEST_DIR}/tmp/target"
export SCRIPT="${PROJECT_DIR}/watch_vpagd.sh"

export VPAGD2ODT_BIN="${TEST_DIR}/tmp/mock_vpagd2odt.sh"
export LOG_FILE="${TEST_DIR}/tmp/test.log"

mkdir -p "${SRC_DIR}/subdir"
mkdir -p "${TARGET_DIR}"
mkdir -p "${TEST_DIR}/tmp"

clean_tmp() {
    rm -rf "${TEST_DIR}/tmp"
    mkdir -p "${SRC_DIR}/subdir"
    mkdir -p "${TARGET_DIR}"
}

setup() {
    clean_tmp

    cat > "${VPAGD2ODT_BIN}" << 'MOCK'
#!/bin/bash
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <source> <target>" >&2
    exit 1
fi
touch "$2"
exit 0
MOCK
    chmod +x "${VPAGD2ODT_BIN}"
}

teardown() {
    clean_tmp
}

log_test() {
    local status="$1"
    local test_name="$2"
    shift 2
    echo "[${status}] ${test_name}"
    if [[ "$#" -gt 0 ]]; then
        echo "  $@"
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo "ASSERTION FAILED: $message"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File does not exist}"

    if [[ -f "$file" ]]; then
        return 0
    else
        echo "ASSERTION FAILED: $message"
        echo "  File: $file"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist}"

    if [[ ! -f "$file" ]]; then
        return 0
    else
        echo "ASSERTION FAILED: $message"
        echo "  File: $file"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"

    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        echo "ASSERTION FAILED: $message"
        echo "  Haystack: '$haystack'"
        echo "  Needle: '$needle'"
        return 1
    fi
}

create_vpagd_file() {
    local filename="$1"
    local dir="${2:-${SRC_DIR}}"
    touch "${dir}/${filename}"
}
