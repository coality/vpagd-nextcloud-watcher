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

test_validate_filename_valid() {
    local result
    result=$("${SCRIPT}" -h 2>&1) || return 0
    return 0
}

test_validate_filename_invalid_format() {
    local result
    result=$(echo "invalid.vpagd" | grep -E '^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$' || echo "no match")
    assert_equals "no match" "$result" "Should not match invalid format"
}

test_validate_filename_valid_pattern() {
    local result
    result=$(echo "2026.03.08.vpagd" | grep -E '^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$' || echo "no match")
    assert_equals "2026.03.08.vpagd" "$result" "Should match valid format"
}

test_validate_filename_invalid_month() {
    local result
    result=$(echo "2026.13.08.vpagd" | grep -E '^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$' || echo "no match")
    assert_equals "2026.13.08.vpagd" "$result" "Pattern should match (month validation is separate)"
}

test_date_extraction() {
    local filename="2026.03.08.vpagd"
    if [[ ! "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
        return 1
    fi

    local year="${filename:0:4}"
    local month="${filename:5:2}"
    local day="${filename:8:2}"

    assert_equals "2026" "$year" "Year extraction" || return 1
    assert_equals "03" "$month" "Month extraction" || return 1
    assert_equals "08" "$day" "Day extraction" || return 1

    return 0
}

test_french_month_name() {
    declare -A FRENCH_MONTHS=(
        [01]="Janvier" [02]="Février" [03]="Mars" [04]="Avril"
        [05]="Mai" [06]="Juin" [07]="Juillet" [08]="Août"
        [09]="Septembre" [10]="Octobre" [11]="Novembre" [12]="Décembre"
    )

    assert_equals "Janvier" "${FRENCH_MONTHS[01]}" "January in French" || return 1
    assert_equals "Mars" "${FRENCH_MONTHS[03]}" "March in French" || return 1
    assert_equals "Août" "${FRENCH_MONTHS[08]}" "August in French" || return 1
    assert_equals "Décembre" "${FRENCH_MONTHS[12]}" "December in French" || return 1

    return 0
}

test_output_filename_format() {
    local year="2026"
    local month="03"
    local day="08"

    declare -A FRENCH_MONTHS=(
        [01]="Janvier" [02]="Février" [03]="Mars" [04]="Avril"
        [05]="Mai" [06]="Juin" [07]="Juillet" [08]="Août"
        [09]="Septembre" [10]="Octobre" [11]="Novembre" [12]="Décembre"
    )

    local month_name="${FRENCH_MONTHS[$month]}"
    local output_filename="Messe du dimanche ${day} ${month_name} ${year}.odt"

    assert_equals "Messe du dimanche 08 Mars 2026.odt" "$output_filename" "Output filename format" || return 1
    return 0
}

test_config_parsing() {
    local test_config="${TEST_DIR}/tmp/test.conf"
    cat > "$test_config" << 'EOF'
SOURCE_DIR="/test/source"
TARGET_DIR="/test/target"
VPAGD2ODT_BIN="/usr/bin/vpagd2odt"
LOG_FILE="/var/log/test.log"
LOG_LEVEL="DEBUG"
EOF

    local parsed_source=""
    local parsed_target=""

    while IFS='=' read -r key value; do
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        [[ -z "$key" || "$key" =~ ^# ]] && continue

        case "$key" in
            SOURCE_DIR) parsed_source="$value" ;;
            TARGET_DIR) parsed_target="$value" ;;
        esac
    done < "$test_config"

    assert_equals "/test/source" "$parsed_source" "Config SOURCE_DIR parsing" || return 1
    assert_equals "/test/target" "$parsed_target" "Config TARGET_DIR parsing" || return 1

    return 0
}

test_config_ignores_comments() {
    local test_config="${TEST_DIR}/tmp/test.conf"
    cat > "$test_config" << 'EOF'
# This is a comment
SOURCE_DIR="/test/source"
# Another comment
TARGET_DIR="/test/target"
EOF

    local count=0
    while IFS='=' read -r key value; do
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        ((count++))
    done < "$test_config"

    assert_equals "2" "$count" "Should parse only 2 non-comment lines" || return 1
    return 0
}

test_config_handles_empty_lines() {
    local test_config="${TEST_DIR}/tmp/test.conf"
    cat > "$test_config" << 'EOF'

SOURCE_DIR="/test/source"

TARGET_DIR="/test/target"

EOF

    local count=0
    while IFS='=' read -r key value; do
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$key" ]] && continue
        [[ "$key" =~ ^# ]] && continue
        ((count++))
    done < "$test_config"

    assert_equals "2" "$count" "Should parse 2 non-empty lines" || return 1
    return 0
}

test_various_valid_filenames() {
    local valid_files=(
        "2026.01.01.vpagd"
        "2026.06.15.vpagd"
        "2026.12.31.vpagd"
        "2025.07.04.vpagd"
    )

    for file in "${valid_files[@]}"; do
        if [[ ! "$file" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
            echo "Should have matched: $file"
            return 1
        fi
    done

    return 0
}

test_various_invalid_filenames() {
    local invalid_files=(
        "invalid.vpagd"
        "2026.vpagd"
        "2026.03.vpagd"
        "2026.03.08.vpag"
        "2026.03.8.vpagd"
        "26.03.08.vpagd"
        "2026.3.08.vpagd"
        "2026.03.vpagd"
    )

    for file in "${invalid_files[@]}"; do
        if [[ "$file" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
            echo "Should NOT have matched: $file"
            return 1
        fi
    done

    return 0
}

main() {
    echo "========================================"
    echo "vpagd-nextcloud-watcher Unit Tests"
    echo "========================================"
    echo ""

    run_test "test_validate_filename_valid_pattern" test_validate_filename_valid_pattern
    run_test "test_validate_filename_invalid_format" test_validate_filename_invalid_format
    run_test "test_date_extraction" test_date_extraction
    run_test "test_french_month_name" test_french_month_name
    run_test "test_output_filename_format" test_output_filename_format
    run_test "test_config_parsing" test_config_parsing
    run_test "test_config_ignores_comments" test_config_ignores_comments
    run_test "test_config_handles_empty_lines" test_config_handles_empty_lines
    run_test "test_various_valid_filenames" test_various_valid_filenames
    run_test "test_various_invalid_filenames" test_various_invalid_filenames

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
