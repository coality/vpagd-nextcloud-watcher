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

test_filename_matches_exact_pattern() {
    local filename="2026.03.08.vpagd"
    if [[ "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
        return 0
    fi
    return 1
}

test_filename_rejects_missing_dots() {
    local filename="20260308.vpagd"
    if [[ "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
        return 1
    fi
    return 0
}

test_filename_rejects_wrong_extension() {
    local filename="2026.03.08.txt"
    if [[ "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
        return 1
    fi
    return 0
}

test_filename_rejects_short_year() {
    local filename="26.03.08.vpagd"
    if [[ "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
        return 1
    fi
    return 0
}

test_filename_rejects_long_year() {
    local filename="20226.03.08.vpagd"
    if [[ "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
        return 1
    fi
    return 0
}

test_filename_rejects_text_instead_of_numbers() {
    local filename="abcd.ef.gh.vpagd"
    if [[ "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
        return 1
    fi
    return 0
}

test_filename_accepts_all_months() {
    local months=("01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12")

    for month in "${months[@]}"; do
        local filename="2026.${month}.15.vpagd"
        if [[ ! "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
            echo "Should have accepted month: $month"
            return 1
        fi
    done

    return 0
}

test_filename_rejects_invalid_month_00() {
    local filename="2026.00.08.vpagd"
    if [[ "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
        return 0
    fi
    return 1
}

test_filename_rejects_invalid_month_13() {
    local filename="2026.13.08.vpagd"
    if [[ "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
        return 0
    fi
    return 1
}

test_filename_accepts_all_valid_days() {
    local days=("01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21" "22" "23" "24" "25" "26" "27" "28" "29" "30" "31")

    for day in "${days[@]}"; do
        local filename="2026.03.${day}.vpagd"
        if [[ ! "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
            echo "Should have accepted day: $day"
            return 1
        fi
    done

    return 0
}

test_filename_rejects_invalid_day_00() {
    local filename="2026.03.00.vpagd"
    if [[ "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
        return 0
    fi
    return 1
}

test_filename_rejects_invalid_day_32() {
    local filename="2026.03.32.vpagd"
    if [[ "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
        return 0
    fi
    return 1
}

test_filename_rejects_single_digit_month() {
    local filename="2026.3.08.vpagd"
    if [[ "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
        return 1
    fi
    return 0
}

test_filename_rejects_single_digit_day() {
    local filename="2026.03.8.vpagd"
    if [[ "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
        return 1
    fi
    return 0
}

test_filename_rejects_no_extension() {
    local filename="2026.03.08"
    if [[ "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
        return 1
    fi
    return 0
}

test_filename_rejects_uppercase_extension() {
    local filename="2026.03.08.VPAGD"
    if [[ "$filename" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.vpagd$ ]]; then
        return 1
    fi
    return 0
}

main() {
    echo "========================================"
    echo "Filename Validation Unit Tests"
    echo "========================================"
    echo ""

    run_test "test_filename_matches_exact_pattern" test_filename_matches_exact_pattern
    run_test "test_filename_rejects_missing_dots" test_filename_rejects_missing_dots
    run_test "test_filename_rejects_wrong_extension" test_filename_rejects_wrong_extension
    run_test "test_filename_rejects_short_year" test_filename_rejects_short_year
    run_test "test_filename_rejects_long_year" test_filename_rejects_long_year
    run_test "test_filename_rejects_text_instead_of_numbers" test_filename_rejects_text_instead_of_numbers
    run_test "test_filename_accepts_all_months" test_filename_accepts_all_months
    run_test "test_filename_accepts_all_valid_days" test_filename_accepts_all_valid_days
    run_test "test_filename_rejects_single_digit_month" test_filename_rejects_single_digit_month
    run_test "test_filename_rejects_single_digit_day" test_filename_rejects_single_digit_day
    run_test "test_filename_rejects_no_extension" test_filename_rejects_no_extension
    run_test "test_filename_rejects_uppercase_extension" test_filename_rejects_uppercase_extension

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
