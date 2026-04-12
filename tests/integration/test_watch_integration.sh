#!/bin/bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${TEST_DIR}/.." && pwd)"

source "${TEST_DIR}/../test_helper.sh"

FAILED=0
PASSED=0
TEST_TIMEOUT=30

run_integration_test() {
    local test_name="$1"
    shift

    echo ""
    echo "Running: $test_name"
    echo "----------------------------------------"

    setup

    local result=0
    local timeout_pid=""

    (
        "$@"
    ) &
    timeout_pid=$!

    (
        sleep "$TEST_TIMEOUT"
        kill -ALRM "$timeout_pid" 2>/dev/null || true
    ) &
    local watchdog_pid=$!

    wait "$timeout_pid" 2>/dev/null || result=1

    kill "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true

    if [[ $result -eq 0 ]]; then
        log_test "PASS" "$test_name"
        ((PASSED++))
    else
        log_test "FAIL" "$test_name"
        ((FAILED++))
    fi

    teardown
    return $result
}

test_watcher_detects_new_file() {
    local config_file="${TEST_DIR}/tmp/test_watcher.conf"
    cat > "$config_file" << EOF
SOURCE_DIR="${SRC_DIR}"
TARGET_DIR="${TARGET_DIR}"
VPAGD2ODT_BIN="${VPAGD2ODT_BIN}"
LOG_FILE="${LOG_FILE}"
LOG_LEVEL="DEBUG"
EOF

    local output_file="${TARGET_DIR}/Messe du dimanche 08 Mars 2026.odt"

    timeout 5 "${SCRIPT}" -c "$config_file" &
    local watcher_pid=$!

    sleep 1

    touch "${SRC_DIR}/2026.03.08.vpagd"

    sleep 2

    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true

    if [[ -f "$output_file" ]]; then
        return 0
    else
        echo "Expected output file not found: $output_file"
        return 1
    fi
}

test_watcher_detects_file_in_subdirectory() {
    local config_file="${TEST_DIR}/tmp/test_watcher.conf"
    cat > "$config_file" << EOF
SOURCE_DIR="${SRC_DIR}"
TARGET_DIR="${TARGET_DIR}"
VPAGD2ODT_BIN="${VPAGD2ODT_BIN}"
LOG_FILE="${LOG_FILE}"
LOG_LEVEL="DEBUG"
EOF

    local output_file="${TARGET_DIR}/Messe du dimanche 15 Avril 2026.odt"

    timeout 5 "${SCRIPT}" -c "$config_file" &
    local watcher_pid=$!

    sleep 1

    mkdir -p "${SRC_DIR}/subdir"
    touch "${SRC_DIR}/subdir/2026.04.15.vpagd"

    sleep 2

    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true

    if [[ -f "$output_file" ]]; then
        return 0
    else
        echo "Expected output file not found: $output_file"
        return 1
    fi
}

test_watcher_regenerates_on_modification() {
    local config_file="${TEST_DIR}/tmp/test_watcher.conf"
    cat > "$config_file" << EOF
SOURCE_DIR="${SRC_DIR}"
TARGET_DIR="${TARGET_DIR}"
VPAGD2ODT_BIN="${VPAGD2ODT_BIN}"
LOG_FILE="${LOG_FILE}"
LOG_LEVEL="DEBUG"
EOF

    local output_file="${TARGET_DIR}/Messe du dimanche 08 Mars 2026.odt"

    timeout 8 "${SCRIPT}" -c "$config_file" &
    local watcher_pid=$!

    sleep 1

    touch "${SRC_DIR}/2026.03.08.vpagd"
    sleep 1
    local first_mtime=$(stat -c %Y "$output_file" 2>/dev/null || echo "0")

    sleep 2

    touch "${SRC_DIR}/2026.03.08.vpagd"
    sleep 1
    local second_mtime=$(stat -c %Y "$output_file" 2>/dev/null || echo "0")

    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true

    if [[ "$second_mtime" -gt "$first_mtime" ]]; then
        return 0
    else
        echo "File was not regenerated after modification"
        echo "First mtime: $first_mtime, Second mtime: $second_mtime"
        return 1
    fi
}

test_watcher_ignores_invalid_filename() {
    local config_file="${TEST_DIR}/tmp/test_watcher.conf"
    cat > "$config_file" << EOF
SOURCE_DIR="${SRC_DIR}"
TARGET_DIR="${TARGET_DIR}"
VPAGD2ODT_BIN="${VPAGD2ODT_BIN}"
LOG_FILE="${LOG_FILE}"
LOG_LEVEL="DEBUG"
EOF

    timeout 5 "${SCRIPT}" -c "$config_file" &
    local watcher_pid=$!

    sleep 1

    touch "${SRC_DIR}/invalid.vpagd"
    touch "${SRC_DIR}/2026.03.vpagd"
    touch "${SRC_DIR}/notvpagd.txt"

    sleep 2

    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true

    local output_files
    output_files=$(find "${TARGET_DIR}" -name "*.odt" 2>/dev/null | wc -l)

    if [[ "$output_files" -eq 0 ]]; then
        return 0
    else
        echo "Invalid filenames should not produce output files, but found: $output_files"
        return 1
    fi
}

test_watcher_uses_close_write_event() {
    local config_file="${TEST_DIR}/tmp/test_watcher.conf"
    cat > "$config_file" << EOF
SOURCE_DIR="${SRC_DIR}"
TARGET_DIR="${TARGET_DIR}"
VPAGD2ODT_BIN="${VPAGD2ODT_BIN}"
LOG_FILE="${LOG_FILE}"
LOG_LEVEL="DEBUG"
EOF

    local output_file="${TARGET_DIR}/Messe du dimanche 08 Mars 2026.odt"

    timeout 5 "${SCRIPT}" -c "$config_file" &
    local watcher_pid=$!

    sleep 1

    echo "content" > "${SRC_DIR}/2026.03.08.vpagd"

    sleep 2

    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true

    if [[ -f "$output_file" ]]; then
        return 0
    else
        echo "close_write event should trigger conversion"
        return 1
    fi
}

main() {
    echo "========================================"
    echo "vpagd-nextcloud-watcher Integration Tests"
    echo "========================================"
    echo ""
    echo "Note: These tests require inotify-tools and may take"
    echo "several seconds each due to watcher startup times."
    echo ""

    if ! command -v inotifywait &>/dev/null; then
        echo "SKIP: inotifywait not available"
        exit 0
    fi

    run_integration_test "test_watcher_detects_new_file" test_watcher_detects_new_file || true
    run_integration_test "test_watcher_detects_file_in_subdirectory" test_watcher_detects_file_in_subdirectory || true
    run_integration_test "test_watcher_regenerates_on_modification" test_watcher_regenerates_on_modification || true
    run_integration_test "test_watcher_ignores_invalid_filename" test_watcher_ignores_invalid_filename || true
    run_integration_test "test_watcher_uses_close_write_event" test_watcher_uses_close_write_event || true

    echo ""
    echo "========================================"
    echo "Integration Test Results"
    echo "========================================"
    echo "Passed: $PASSED"
    echo "Failed: $FAILED"
    echo ""

    if [[ $FAILED -gt 0 ]]; then
        echo "SOME TESTS FAILED"
        exit 1
    else
        echo "ALL TESTS PASSED"
        exit 0
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
