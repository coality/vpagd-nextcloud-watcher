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

test_conversion_produces_output_file() {
    local source_file="${SRC_DIR}/2026.03.08.vpagd"
    touch "$source_file"

    local target_file="${TARGET_DIR}/Messe du dimanche 08 Mars 2026.odt"

    if [[ ! -f "${VPAGD2ODT_BIN}" ]]; then
        echo "Mock binary not found"
        return 1
    fi

    "${VPAGD2ODT_BIN}" "$source_file" "$target_file"

    assert_file_exists "$target_file" "Output file should be created" || return 1
    return 0
}

test_conversion_overwrites_existing_file() {
    local source_file="${SRC_DIR}/2026.03.08.vpagd"
    touch "$source_file"

    local target_file="${TARGET_DIR}/Messe du dimanche 08 Mars 2026.odt"

    "${VPAGD2ODT_BIN}" "$source_file" "$target_file"
    local first_mtime=$(stat -c %Y "$target_file")

    sleep 1

    "${VPAGD2ODT_BIN}" "$source_file" "$target_file"
    local second_mtime=$(stat -c %Y "$target_file")

    if [[ "$second_mtime" -gt "$first_mtime" ]]; then
        return 0
    fi
    return 1
}

test_conversion_in_subdirectory() {
    local source_file="${SRC_DIR}/subdir/2026.03.08.vpagd"
    touch "$source_file"

    local target_file="${TARGET_DIR}/Messe du dimanche 08 Mars 2026.odt"

    "${VPAGD2ODT_BIN}" "$source_file" "$target_file"

    assert_file_exists "$target_file" "Output file should be created for subdirectory source" || return 1
    return 0
}

test_english_date_output() {
    declare -A ENGLISH_MONTHS=(
        [01]="January" [02]="February" [03]="March" [04]="April"
        [05]="May" [06]="June" [07]="July" [08]="August"
        [09]="September" [10]="October" [11]="November" [12]="December"
    )

    local year="2026"
    local month="03"
    local day="08"

    local day_of_week
    day_of_week=$(date -d "${year}-${month}-${day}" '+%w' 2>/dev/null || echo "0")
    declare -A ENGLISH_DAYS=(
        [0]="sunday" [1]="monday" [2]="tuesday" [3]="wednesday"
        [4]="thursday" [5]="friday" [6]="saturday"
    )
    local day_name="${ENGLISH_DAYS[$day_of_week]:-sunday}"
    local month_name="${ENGLISH_MONTHS[$month]}"

    local expected="${day_name^} Mass ${day} ${month_name} ${year}.odt"
    local actual="Sunday Mass 08 March 2026.odt"

    assert_equals "$expected" "$actual" "English date output format" || return 1
    return 0
}

test_english_all_months() {
    declare -A ENGLISH_MONTHS=(
        [01]="January" [02]="February" [03]="March" [04]="April"
        [05]="May" [06]="June" [07]="July" [08]="August"
        [09]="September" [10]="October" [11]="November" [12]="December"
    )

    local year="2026"
    local day="08"

    for month in "01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12"; do
        local month_name="${ENGLISH_MONTHS[$month]}"
        local pattern="[A-Z][a-z]+ Mass ${day} ${month_name} ${year}.odt"

        if [[ ! "$month_name" =~ ^[A-Z] ]]; then
            echo "Month name should start with uppercase: $month_name"
            return 1
        fi
    done

    return 0
}

test_french_date_output() {
    declare -A FRENCH_MONTHS=(
        [01]="Janvier" [02]="Février" [03]="Mars" [04]="Avril"
        [05]="Mai" [06]="Juin" [07]="Juillet" [08]="Août"
        [09]="Septembre" [10]="Octobre" [11]="Novembre" [12]="Décembre"
    )
    declare -A FRENCH_DAYS=(
        [0]="dimanche" [1]="lundi" [2]="mardi" [3]="mercredi"
        [4]="jeudi" [5]="vendredi" [6]="samedi"
    )

    local year="2026"
    local month="03"
    local day="08"

    local day_of_week
    day_of_week=$(date -d "${year}-${month}-${day}" '+%w' 2>/dev/null || echo "0")
    local day_name="${FRENCH_DAYS[$day_of_week]:-dimanche}"
    local month_name="${FRENCH_MONTHS[$month]}"
    local expected="Messe du ${day_name} ${day} ${month_name} ${year}.odt"
    local actual="Messe du dimanche 08 Mars 2026.odt"

    assert_equals "$expected" "$actual" "French date output format" || return 1
    return 0
}

test_all_months_produce_correct_output() {
    declare -A FRENCH_MONTHS=(
        [01]="Janvier" [02]="Février" [03]="Mars" [04]="Avril"
        [05]="Mai" [06]="Juin" [07]="Juillet" [08]="Août"
        [09]="Septembre" [10]="Octobre" [11]="Novembre" [12]="Décembre"
    )
    declare -A FRENCH_DAYS=(
        [0]="dimanche" [1]="lundi" [2]="mardi" [3]="mercredi"
        [4]="jeudi" [5]="vendredi" [6]="samedi"
    )

    local year="2026"
    local month="03"
    local day="08"
    local day_of_week
    day_of_week=$(date -d "${year}-${month}-${day}" '+%w' 2>/dev/null || echo "0")
    local day_name="${FRENCH_DAYS[$day_of_week]:-dimanche}"

    for m in "01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12"; do
        local month_name="${FRENCH_MONTHS[$m]}"
        local expected="Messe du ${day_name} ${day} ${month_name} ${year}.odt"
        local pattern="Messe du .+ ${day} .+ ${year}.odt"

        if [[ ! "$expected" =~ $pattern ]]; then
            echo "Output format check failed for month $m: $expected"
            return 1
        fi
    done

    return 0
}

test_day_capitalization_lowercase() {
    local output="Messe du dimanche 08 Mars 2026.odt"
    local pattern="^Messe du .+ [0-9]+ .+ [0-9]+\\.odt$"

    if [[ "$output" =~ $pattern ]]; then
        return 0
    fi
    return 1
}

test_month_capitalization() {
    declare -A FRENCH_MONTHS=(
        [01]="Janvier" [02]="Février" [03]="Mars" [04]="Avril"
        [05]="Mai" [06]="Juin" [07]="Juillet" [08]="Août"
        [09]="Septembre" [10]="Octobre" [11]="Novembre" [12]="Décembre"
    )

    for month_num in "01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12"; do
        local month_name="${FRENCH_MONTHS[$month_num]}"
        local first_char="${month_name:0:1}"

        if [[ "$first_char" =~ ^[A-Z] ]]; then
            continue
        else
            echo "Month $month_num should start with uppercase: $month_name"
            return 1
        fi
    done

    return 0
}

test_day_capitalization_is_lowercase() {
    local output="Messe du dimanche 08 Mars 2026.odt"
    local pattern_lowercase="^Messe du dimanche"
    local pattern_uppercase="^Messe du Dimanche"

    if [[ "$output" =~ $pattern_lowercase ]]; then
        return 0
    fi

    if [[ "$output" =~ $pattern_uppercase ]]; then
        echo "Day should be lowercase: 'dimanche' not 'Dimanche'"
        return 1
    fi

    return 1
}

main() {
    echo "========================================"
    echo "Conversion Unit Tests"
    echo "========================================"
    echo ""

    run_test "test_french_date_output" test_french_date_output
    run_test "test_all_months_produce_correct_output" test_all_months_produce_correct_output
    run_test "test_month_capitalization" test_month_capitalization
    run_test "test_day_capitalization_lowercase" test_day_capitalization_lowercase
    run_test "test_day_capitalization_is_lowercase" test_day_capitalization_is_lowercase
    run_test "test_english_date_output" test_english_date_output
    run_test "test_english_all_months" test_english_all_months
    run_test "test_conversion_produces_output_file" test_conversion_produces_output_file
    run_test "test_conversion_overwrites_existing_file" test_conversion_overwrites_existing_file
    run_test "test_conversion_in_subdirectory" test_conversion_in_subdirectory

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
