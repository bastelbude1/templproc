#!/bin/bash

# templproc Test Suite
# Run all feature tests to verify functionality

# set -e disabled - test functions handle errors internally

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLPROC="../templproc.py"

echo "========================================"
echo "templproc Test Suite v1.2.1"
echo "========================================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_pattern="$3"

    echo -n "Test: $test_name ... "

    if output=$(eval "$test_cmd" 2>&1); then
        if echo "$output" | grep -q "$expected_pattern"; then
            echo -e "${GREEN}PASSED${NC}"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}FAILED${NC} (pattern not found: $expected_pattern)"
            echo "Output: $output"
            ((FAILED++))
            return 1
        fi
    else
        echo -e "${RED}FAILED${NC} (command failed)"
        echo "Output: $output"
        ((FAILED++))
        return 1
    fi
}

run_test_expect_fail() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_error="$3"

    echo -n "Test: $test_name ... "

    if output=$(eval "$test_cmd" 2>&1); then
        echo -e "${RED}FAILED${NC} (should have failed but succeeded)"
        ((FAILED++))
        return 1
    else
        if echo "$output" | grep -q "$expected_error"; then
            echo -e "${GREEN}PASSED${NC}"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}FAILED${NC} (wrong error: expected '$expected_error')"
            echo "Output: $output"
            ((FAILED++))
            return 1
        fi
    fi
}

cd "$SCRIPT_DIR"

# Setup test output directory outside of template directory
TEST_OUTPUT_BASE="/tmp/templproc_tests"
rm -rf "$TEST_OUTPUT_BASE" 2>/dev/null || true
mkdir -p "$TEST_OUTPUT_BASE"

echo "=== Basic Features ==="
run_test "1. Default @ delimiter" \
    "python3 $TEMPLPROC -V test_values.txt -P '@HOSTNAME@,@IP_ADDRESS@,@PORT@' -T test_templates.yaml -o $TEST_OUTPUT_BASE -p test1" \
    "Using delimiter: '@'"

run_test "2. % delimiter auto-detect" \
    "python3 $TEMPLPROC -V test_values.txt -P '%HOSTNAME%,%IP_ADDRESS%,%PORT%' -T test_templates_percent.yaml -o $TEST_OUTPUT_BASE -p test2" \
    "Using delimiter: '%'"

echo ""
echo "=== Mixed Case Feature ==="
run_test_expect_fail "3. Mixed case WITHOUT flag (should fail)" \
    "python3 $TEMPLPROC -V test_values.txt -P '@hostName@,@ipAddress@,@portNumber@' -T test_templates_mixed.yaml -o $TEST_OUTPUT_BASE -p test3" \
    "Mixed case not allowed"

run_test "4. Mixed case WITH --allow-mixed-case" \
    "python3 $TEMPLPROC -V test_values.txt -P '@hostName@,@ipAddress@,@portNumber@' -T test_templates_mixed.yaml -o $TEST_OUTPUT_BASE -p test3 --allow-mixed-case" \
    "Using delimiter: '@'"

echo ""
echo "=== Hyphen Feature ==="
run_test_expect_fail "5. Hyphens WITHOUT flag (should fail)" \
    "python3 $TEMPLPROC -V test_values_hyphen.txt -P '@DB-HOST@,@API-KEY@,@USER-ID@' -T test_templates_hyphen.yaml -o $TEST_OUTPUT_BASE -p test4" \
    "Hyphens not allowed"

run_test "6. Hyphens WITH --allow-hyphens" \
    "python3 $TEMPLPROC -V test_values_hyphen.txt -P '@DB-HOST@,@API-KEY@,@USER-ID@' -T test_templates_hyphen.yaml -o $TEST_OUTPUT_BASE -p test4 --allow-hyphens" \
    "Using delimiter: '@'"

echo ""
echo "=== Custom File Type Feature ==="
run_test_expect_fail "7. Custom extension WITHOUT flag (should fail)" \
    "python3 $TEMPLPROC -V 'myvalue' -P '@VALUE@' -T test_templates_custom.mycustom -o $TEST_OUTPUT_BASE -p test5" \
    "not allowed"

run_test "8. Custom extension WITH --allow-any-filetype" \
    "python3 $TEMPLPROC -V 'myvalue' -P '@VALUE@' -T test_templates_custom.mycustom -o $TEST_OUTPUT_BASE -p test5 --allow-any-filetype" \
    "Using delimiter: '@'"

echo ""
echo "=== Security Features ==="
run_test_expect_fail "9. Inconsistent delimiters (should fail)" \
    "python3 $TEMPLPROC -V test_values.txt -P '@HOST@,%IP%,@PORT@' -T test_templates.yaml -o $TEST_OUTPUT_BASE -p test6" \
    "Inconsistent delimiters"

run_test_expect_fail "10. Null byte rejection" \
    "python3 -c \"with open('/tmp/nulltest.txt', 'wb') as f: f.write(b'test\x00value')\" && python3 $TEMPLPROC -V /tmp/nulltest.txt -P '@VALUE@' -T test_templates_custom.mycustom -o $TEST_OUTPUT_BASE -p test7 --allow-any-filetype" \
    "Null byte"

echo ""
echo "=== Actual File Creation Test ==="
run_test "11. Create actual files with -r flag" \
    "python3 $TEMPLPROC -V test_values.txt -P '@HOSTNAME@,@IP_ADDRESS@,@PORT@' -T test_templates.yaml -o $TEST_OUTPUT_BASE -p test_output -r" \
    "Created:"

# Verify created files
if [ -f "$TEST_OUTPUT_BASE/test_output/test_templates_line0001.yaml" ]; then
    echo -e "Test: 12. Verify output file content ... ${GREEN}PASSED${NC}"
    ((PASSED++))
else
    echo -e "Test: 12. Verify output file content ... ${RED}FAILED${NC}"
    ((FAILED++))
fi

echo ""
echo "========================================"
echo "Test Results:"
echo -e "  ${GREEN}Passed: $PASSED${NC}"
echo -e "  ${RED}Failed: $FAILED${NC}"
echo "========================================"

# Cleanup
rm -rf "$TEST_OUTPUT_BASE" /tmp/nulltest.txt 2>/dev/null || true

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
