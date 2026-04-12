#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export PATH="${PROJECT_DIR}:${PATH}"

echo "========================================"
echo "vpagd-nextcloud-watcher Test Runner"
echo "========================================"
echo ""

cd "${PROJECT_DIR}"

UNIT_TESTS="${SCRIPT_DIR}/unit"
INTEGRATION_TESTS="${SCRIPT_DIR}/integration"

FAILED=0
PASSED=0

run_test_suite() {
    local name="$1"
    local test_path="$2"

    echo ""
    echo "========================================"
    echo "Running ${name}"
    echo "========================================"

    if [[ ! -d "$test_path" ]]; then
        echo "No ${name} found at: ${test_path}"
        return
    fi

    local test_count=0
    for test_file in "${test_path}"/*.sh; do
        if [[ -f "$test_file" && "$test_file" != *"test_helper"* ]]; then
            test_count=$((test_count + 1))
        fi
    done

    if [[ $test_count -eq 0 ]]; then
        echo "No tests found in: ${test_path}"
        return
    fi

    echo "Found ${test_count} test file(s)"
    echo ""

    for test_file in "${test_path}"/*.sh; do
        if [[ -f "$test_file" && "$test_file" != *"test_helper"* ]]; then
            if bash "$test_file"; then
                PASSED=$((PASSED + 1))
            else
                FAILED=$((FAILED + 1))
            fi
        fi
    done
}

if [[ "$#" -eq 0 || "$1" == "unit" || "$1" == "all" ]]; then
    run_test_suite "Unit Tests" "${UNIT_TESTS}"
fi

if [[ "$#" -eq 0 || "$1" == "integration" || "$1" == "all" ]]; then
    run_test_suite "Integration Tests" "${INTEGRATION_TESTS}"
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo ""
    echo "Usage: $0 [suite]"
    echo ""
    echo "Suites:"
    echo "  unit         Run unit tests only (default if no args)"
    echo "  integration  Run integration tests only"
    echo "  all          Run all tests (default if no args)"
    echo ""
    echo "Examples:"
    echo "  $0              Run all tests"
    echo "  $0 unit         Run unit tests only"
    echo "  $0 integration  Run integration tests only"
    exit 0
fi

echo ""
echo "========================================"
echo "Overall Results"
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
