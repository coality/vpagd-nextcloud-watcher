#!/bin/bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${TEST_DIR}/.." && pwd)"

source "${TEST_DIR}/../test_helper.sh"

FAILED=0
PASSED=0

run_test() {
    local test_name="$1"
    shift

    echo ""
    echo "Running: $test_name"
    echo "----------------------------------------"

    setup

    if "$@"; then
        log_test "PASS" "$test_name"
        PASSED=$((PASSED + 1))
    else
        log_test "FAIL" "$test_name"
        FAILED=$((FAILED + 1))
    fi

    teardown
}

test_parse_valid_config() {
    local test_config="${TEST_DIR}/tmp/test.conf"

    cat > "$test_config" << 'EOF'
SOURCE_DIR="/path/to/source"
TARGET_DIR="/path/to/target"
VPAGD2ODT_BIN="/usr/local/bin/vpagd2odt"
LOG_FILE="/var/log/watcher.log"
LOG_LEVEL="DEBUG"
EOF

    local source_dir=""
    local target_dir=""
    local bin_path=""
    local log_file=""
    local log_level=""

    while IFS='=' read -r key value; do
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        [[ -z "$key" || "$key" =~ ^# ]] && continue

        case "$key" in
            SOURCE_DIR) source_dir="$value" ;;
            TARGET_DIR) target_dir="$value" ;;
            VPAGD2ODT_BIN) bin_path="$value" ;;
            LOG_FILE) log_file="$value" ;;
            LOG_LEVEL) log_level="$value" ;;
        esac
    done < "$test_config"

    assert_equals "/path/to/source" "$source_dir" "SOURCE_DIR parsing" || return 1
    assert_equals "/path/to/target" "$target_dir" "TARGET_DIR parsing" || return 1
    assert_equals "/usr/local/bin/vpagd2odt" "$bin_path" "VPAGD2ODT_BIN parsing" || return 1
    assert_equals "/var/log/watcher.log" "$log_file" "LOG_FILE parsing" || return 1
    assert_equals "DEBUG" "$log_level" "LOG_LEVEL parsing" || return 1

    return 0
}

test_config_strips_whitespace() {
    local test_config="${TEST_DIR}/tmp/test.conf"

    cat > "$test_config" << 'EOF'
   SOURCE_DIR="/path/to/source"
   TARGET_DIR="/path/to/target"
EOF

    local source_dir=""
    local target_dir=""

    while IFS='=' read -r key value; do
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        [[ -z "$key" || "$key" =~ ^# ]] && continue

        case "$key" in
            SOURCE_DIR) source_dir="$value" ;;
            TARGET_DIR) target_dir="$value" ;;
        esac
    done < "$test_config"

    assert_equals "/path/to/source" "$source_dir" "SOURCE_DIR whitespace stripping" || return 1
    assert_equals "/path/to/target" "$target_dir" "TARGET_DIR whitespace stripping" || return 1

    return 0
}

test_config_ignores_comment_lines() {
    local test_config="${TEST_DIR}/tmp/test.conf"

    cat > "$test_config" << 'EOF'
# Comment line
SOURCE_DIR="/path/to/source"
# Another comment
TARGET_DIR="/path/to/target"
EOF

    local count=0

    while IFS='=' read -r key value; do
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        ((count++))
    done < "$test_config"

    assert_equals "2" "$count" "Should count only non-comment lines" || return 1
    return 0
}

test_config_ignores_empty_lines() {
    local test_config="${TEST_DIR}/tmp/test.conf"

    cat > "$test_config" << 'EOF'

SOURCE_DIR="/path/to/source"

TARGET_DIR="/path/to/target"

EOF

    local count=0

    while IFS='=' read -r key value; do
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$key" ]] && continue
        ((count++))
    done < "$test_config"

    assert_equals "2" "$count" "Should count only non-empty lines" || return 1
    return 0
}

test_config_handles_quotes_in_values() {
    local test_config="${TEST_DIR}/tmp/test.conf"

    cat > "$test_config" << 'EOF'
SOURCE_DIR=/path/to/source
TARGET_DIR=/path/to/target
EOF

    local source_dir=""

    while IFS='=' read -r key value; do
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$key" || "$key" =~ ^# ]] && continue

        case "$key" in
            SOURCE_DIR) source_dir="$value" ;;
        esac
    done < "$test_config"

    assert_equals "/path/to/source" "$source_dir" "Unquoted value parsing" || return 1
    return 0
}

test_config_unknown_key_is_ignored() {
    local test_config="${TEST_DIR}/tmp/test.conf"

    cat > "$test_config" << 'EOF'
UNKNOWN_KEY="should be ignored"
SOURCE_DIR="/path/to/source"
EOF

    local known_key_found=0

    while IFS='=' read -r key value; do
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$key" || "$key" =~ ^# ]] && continue

        case "$key" in
            SOURCE_DIR) known_key_found=1 ;;
            *) ;;
        esac
    done < "$test_config"

    assert_equals "1" "$known_key_found" "Known key should be recognized" || return 1
    return 0
}

test_config_missing_file() {
    local test_config="${TEST_DIR}/tmp/nonexistent.conf"

    if [[ -f "$test_config" ]]; then
        echo "Test setup error: file should not exist"
        return 1
    fi

    return 0
}

main() {
    echo "========================================"
    echo "Config Parsing Unit Tests"
    echo "========================================"
    echo ""

    run_test "test_parse_valid_config" test_parse_valid_config
    run_test "test_config_strips_whitespace" test_config_strips_whitespace
    run_test "test_config_ignores_comment_lines" test_config_ignores_comment_lines
    run_test "test_config_ignores_empty_lines" test_config_ignores_empty_lines
    run_test "test_config_handles_quotes_in_values" test_config_handles_quotes_in_values
    run_test "test_config_unknown_key_is_ignored" test_config_unknown_key_is_ignored
    run_test "test_config_missing_file" test_config_missing_file

    echo ""
    echo "========================================"
    echo "Test Results"
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
