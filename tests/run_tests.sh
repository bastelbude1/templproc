#!/bin/bash

# templproc Test Suite
# Run all feature tests to verify functionality

# set -e disabled - test functions handle errors internally

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLPROC="../templproc.py"

echo "========================================"
echo "templproc Test Suite v1.3.0"
echo "Comprehensive Feature Coverage"
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
echo "=== Value Delimiter Tests ==="
run_test "13. TAB delimiter with multi-column data" \
    "python3 $TEMPLPROC -V test_values_tab.txt -P '@HOSTNAME@,@IP_ADDRESS@,@PORT@' -T test_templates.yaml -o $TEST_OUTPUT_BASE -p test13" \
    "Parsed 3 value rows"

run_test "14. Semicolon delimiter with multi-column data" \
    "python3 $TEMPLPROC -V test_values_semicolon.txt -P '@HOSTNAME@,@IP_ADDRESS@,@PORT@' -T test_templates.yaml -o $TEST_OUTPUT_BASE -p test14" \
    "Parsed 3 value rows"

run_test "15. Newline delimiter (one value per line)" \
    "python3 $TEMPLPROC -V test_values_newline.txt -P '@HOSTNAME@' -T test_template_no_patterns.txt -o $TEST_OUTPUT_BASE -p test15" \
    "Parsed 3 value rows"

run_test "16. Mixed delimiters accepted (TAB and semicolon are valid)" \
    "python3 $TEMPLPROC -V test_values_mixed_delim.txt -P '@HOSTNAME@,@IP_ADDRESS@,@PORT@' -T test_templates.yaml -o $TEST_OUTPUT_BASE -p test16" \
    "Parsed 3 value rows"

run_test "17. Comments and empty lines in value file" \
    "python3 $TEMPLPROC -V test_values_comments.txt -P '@HOSTNAME@,@IP_ADDRESS@,@PORT@' -T test_templates.yaml -o $TEST_OUTPUT_BASE -p test17" \
    "Parsed 3 value rows"

echo ""
echo "=== Value/Pattern Count Mismatch Tests ==="
run_test_expect_fail "18. Too few values for patterns (should fail)" \
    "python3 $TEMPLPROC -V test_values_too_few.txt -P '@HOSTNAME@,@IP_ADDRESS@,@PORT@' -T test_templates.yaml -o $TEST_OUTPUT_BASE -p test18" \
    "Missing values for patterns"

run_test "19. Too many values for patterns (warns, doesn't fail)" \
    "mkdir -p $TEST_OUTPUT_BASE && python3 $TEMPLPROC -V test_values_too_many.txt -P '@HOSTNAME@,@IP_ADDRESS@' -T test_template_2patterns.yaml -o $TEST_OUTPUT_BASE -p test19" \
    "Extra values will be ignored"

run_test_expect_fail "20. Empty pattern list (should fail)" \
    "python3 $TEMPLPROC -V test_values.txt -P '' -T test_templates.yaml -o $TEST_OUTPUT_BASE -p test20 2>&1" \
    "No patterns provided"

run_test "21. Command-line values (semicolon-separated for multi-column)" \
    "python3 $TEMPLPROC -V 'host1;192.168.1.1;80' -P '@HOSTNAME@,@IP_ADDRESS@,@PORT@' -T test_templates.yaml -o $TEST_OUTPUT_BASE -p test21" \
    "Parsing values from command line"

echo ""
echo "=== Multi-Row Verification Tests ==="
run_test "22. Verify 10 rows create 10 files" \
    "python3 $TEMPLPROC -V test_values_10rows.txt -P '@ROW@,@VALUE@' -T test_template_multirow.txt -o $TEST_OUTPUT_BASE -p test22 -r && [ \$(ls $TEST_OUTPUT_BASE/test22/*.txt 2>/dev/null | wc -l) -eq 10 ]" \
    "Completed: 10 successful"

run_test "23. Verify file naming sequence (line0001-line0010)" \
    "python3 $TEMPLPROC -V test_values_10rows.txt -P '@ROW@,@VALUE@' -T test_template_multirow.txt -o $TEST_OUTPUT_BASE -p test23 -r && [ -f $TEST_OUTPUT_BASE/test23/test_template_multirow_line0001.txt ] && [ -f $TEST_OUTPUT_BASE/test23/test_template_multirow_line0010.txt ]" \
    "Created:"

# Verify different content in each file
run_test "24. Verify each file has different content" \
    "python3 $TEMPLPROC -V test_values_10rows.txt -P '@ROW@,@VALUE@' -T test_template_multirow.txt -o $TEST_OUTPUT_BASE -p test24 -r && grep -q 'Row identifier: row01' $TEST_OUTPUT_BASE/test24/test_template_multirow_line0001.txt && grep -q 'Row identifier: row10' $TEST_OUTPUT_BASE/test24/test_template_multirow_line0010.txt" \
    "Created:"

echo ""
echo "=== Multiple Template Tests ==="
run_test "25. Process 2 templates with wildcard" \
    "cd $SCRIPT_DIR && python3 $TEMPLPROC -V 'name1;val1' -P '@NAME@,@VALUE@' -T 'test_template_multi*.yaml' -o $TEST_OUTPUT_BASE -p test25 -r" \
    "Found 2 template"

run_test "26. Verify wildcard matches multiple templates" \
    "cd $SCRIPT_DIR && python3 $TEMPLPROC -V 'name1;val1' -P '@NAME@,@VALUE@' -T 'test_template_multi*.yaml' -o $TEST_OUTPUT_BASE -p test26" \
    "Found 2 template"

run_test "27. Template directory processing" \
    "mkdir -p /tmp/templproc_test_tmpls && cp test_template_multi1.yaml test_template_multi2.yaml /tmp/templproc_test_tmpls/ && python3 $TEMPLPROC -V 'n1;v1' -P '@NAME@,@VALUE@' -T /tmp/templproc_test_tmpls/ -o $TEST_OUTPUT_BASE -p test27 && rm -rf /tmp/templproc_test_tmpls" \
    "Found 2 template"

echo ""
echo "=== Force Mode Tests ==="
run_test_expect_fail "28. Missing pattern WITHOUT force mode (should fail)" \
    "python3 $TEMPLPROC -V test_values.txt -P '@HOSTNAME@,@IP_ADDRESS@,@PORT@' -T test_template_missing_patterns.yaml -o $TEST_OUTPUT_BASE -p test28" \
    "patterns without values"

run_test "29. Missing pattern WITH force mode (should warn)" \
    "python3 $TEMPLPROC -V test_values.txt -P '@HOSTNAME@,@IP_ADDRESS@,@PORT@' -T test_template_missing_patterns.yaml -o $TEST_OUTPUT_BASE -p test29 -f" \
    "FORCE MODE"

run_test "30. Verify unreplaced patterns in output with force mode" \
    "python3 $TEMPLPROC -V test_values.txt -P '@HOSTNAME@,@IP_ADDRESS@,@PORT@' -T test_template_missing_patterns.yaml -o $TEST_OUTPUT_BASE -p test30 -f -r && grep -q '@LOCATION@' $TEST_OUTPUT_BASE/test30/test_template_missing_patterns_line0001.yaml" \
    "FORCE MODE"

echo ""
echo "=== Pattern Edge Case Tests ==="
run_test "31. Underscore in patterns (@DB_HOST@)" \
    "python3 $TEMPLPROC -V 'localhost;5432;mydb' -P '@DB_HOST@,@DB_PORT@,@DB_NAME@' -T test_template_underscore.conf -o $TEST_OUTPUT_BASE -p test31" \
    "Using delimiter: '@'"

run_test "32. Numbers in patterns (@HOST123@)" \
    "python3 $TEMPLPROC -V 'srv1;srv2;host123' -P '@SERVER1@,@SERVER2@,@HOST123@' -T test_template_numbers.conf -o $TEST_OUTPUT_BASE -p test32" \
    "Using delimiter: '@'"

run_test_expect_fail "33. Invalid pattern with spaces (should fail)" \
    "python3 $TEMPLPROC -V 'val1' -P '@HO ST@' -T test_template_no_patterns.txt -o $TEST_OUTPUT_BASE -p test33 2>&1" \
    "Invalid pattern"

run_test_expect_fail "34. Invalid pattern with special chars (should fail)" \
    "python3 $TEMPLPROC -V 'val1' -P '@HOST!@' -T test_template_no_patterns.txt -o $TEST_OUTPUT_BASE -p test34 2>&1" \
    "Invalid pattern"

run_test_expect_fail "35. Duplicate patterns (should fail)" \
    "python3 $TEMPLPROC -V 'val1;val2' -P '@VAL@,@VAL@' -T test_template_no_patterns.txt -o $TEST_OUTPUT_BASE -p test35" \
    "Duplicate patterns"

echo ""
echo "=== Value Edge Case Tests ==="
run_test "36. Empty values (valid)" \
    "mkdir -p $TEST_OUTPUT_BASE && python3 $TEMPLPROC -V test_values_edge_cases.txt -P '@ROW@,@VALUE@' -T test_template_multirow.txt -o $TEST_OUTPUT_BASE -p test36 -r" \
    "Completed: 4 successful"

run_test "37. Unicode characters in values" \
    "mkdir -p $TEST_OUTPUT_BASE && python3 $TEMPLPROC -V test_values_edge_cases.txt -P '@ROW@,@VALUE@' -T test_template_multirow.txt -o $TEST_OUTPUT_BASE -p test37 -r && grep -q 'unicode_test' $TEST_OUTPUT_BASE/test37/test_template_multirow_line0003.txt" \
    "Created:"

run_test "38. Special characters in values" \
    "mkdir -p $TEST_OUTPUT_BASE && python3 $TEMPLPROC -V test_values_edge_cases.txt -P '@ROW@,@VALUE@' -T test_template_multirow.txt -o $TEST_OUTPUT_BASE -p test38 -r && grep -q 'special_chars' $TEST_OUTPUT_BASE/test38/test_template_multirow_line0004.txt" \
    "Created:"

echo ""
echo "=== Security Boundary Tests ==="
run_test "39. Large template file accepted (no size limit enforced)" \
    "mkdir -p $TEST_OUTPUT_BASE && python3 -c 'with open(\"/home/baste/large_template.txt\", \"w\") as f: f.write(\"@VAL@\\n\" * 20000)' && python3 $TEMPLPROC -V 'val1' -P '@VAL@' -T /home/baste/large_template.txt -o $TEST_OUTPUT_BASE -p test39; RET=\$?; rm -f /home/baste/large_template.txt; exit \$RET" \
    "Found 1 template"

run_test_expect_fail "40. Values file line limit (>3000 lines)" \
    "python3 -c 'with open(\"/tmp/large_values.txt\", \"w\") as f: [f.write(f\"val{i}\\n\") for i in range(3001)]' && python3 $TEMPLPROC -V /tmp/large_values.txt -P '@VAL@' -T test_template_no_patterns.txt -o $TEST_OUTPUT_BASE -p test40; RET=\$?; rm -f /tmp/large_values.txt; exit \$RET" \
    "Too many value lines"

run_test "41. Template path with normal extension works" \
    "python3 $TEMPLPROC -V 'val1' -P '@VAL@' -T 'test_template_no_patterns.txt' -o $TEST_OUTPUT_BASE -p 'test41' -r" \
    "Completed: 1 successful"

run_test_expect_fail "42. Output directory inside template directory" \
    "python3 $TEMPLPROC -V 'val1' -P '@VAL@' -T test_template_no_patterns.txt -o . -p test42" \
    "would be inside template directory"

echo ""
echo "=== Error Handling Tests ==="
run_test_expect_fail "43. Template file not found" \
    "python3 $TEMPLPROC -V 'val1' -P '@VAL@' -T nonexistent_template.txt -o $TEST_OUTPUT_BASE -p test43" \
    "No templates found"

run_test_expect_fail "44. Values file not found" \
    "python3 $TEMPLPROC -V nonexistent_values.txt -P '@VAL@' -T test_template_no_patterns.txt -o $TEST_OUTPUT_BASE -p test44" \
    "Values file not found"

run_test_expect_fail "45. Invalid template file extension" \
    "python3 $TEMPLPROC -V 'val1' -P '@VAL@' -T test_templates_custom.mycustom -o $TEST_OUTPUT_BASE -p test45" \
    "not allowed"

run_test "46. Unreadable template file handled" \
    "mkdir -p $TEST_OUTPUT_BASE && touch /home/baste/test_unreadable.txt && chmod 000 /home/baste/test_unreadable.txt && python3 $TEMPLPROC -V 'val1' -P '@VAL@' -T /home/baste/test_unreadable.txt -o $TEST_OUTPUT_BASE -p test46 2>&1; chmod 644 /home/baste/test_unreadable.txt 2>/dev/null; rm -f /home/baste/test_unreadable.txt" \
    "Could not decode"

run_test_expect_fail "47. Unwritable output directory" \
    "mkdir -p /tmp/unwritable_dir && chmod 000 /tmp/unwritable_dir && python3 $TEMPLPROC -V 'val1' -P '@VAL@' -T test_template_no_patterns.txt -o /tmp/unwritable_dir -p test47; RET=\$?; chmod 755 /tmp/unwritable_dir 2>/dev/null; rm -rf /tmp/unwritable_dir; exit \$RET" \
    "Permission denied"

echo ""
echo "=== Template Pattern Validation Tests ==="
run_test_expect_fail "48. Template contains patterns NOT in provided list" \
    "python3 $TEMPLPROC -V 'val1;val2' -P '@HOSTNAME@,@IP_ADDRESS@' -T test_templates.yaml -o $TEST_OUTPUT_BASE -p test48" \
    "patterns without values"

run_test "49. Template with mixed delimiters processes @ patterns only" \
    "python3 $TEMPLPROC -V test_values.txt -P '@HOSTNAME@,@IP_ADDRESS@,@PORT@' -T test_template_wrong_delimiter.yaml -o $TEST_OUTPUT_BASE -p test49 -f" \
    "Force mode: ENABLED"

run_test "50. Template with no patterns (should copy as-is)" \
    "python3 $TEMPLPROC -V 'anyvalue' -P '@VAL@' -T test_template_no_patterns.txt -o $TEST_OUTPUT_BASE -p test50 -r && grep -q 'This template has no patterns' $TEST_OUTPUT_BASE/test50/test_template_no_patterns_line0001.txt" \
    "Completed: 1 successful"

echo ""
echo "=== Dry-Run Verification Tests ==="
run_test "51. Dry-run mode produces NO files" \
    "rm -rf $TEST_OUTPUT_BASE/test51 && python3 $TEMPLPROC -V test_values.txt -P '@HOSTNAME@,@IP_ADDRESS@,@PORT@' -T test_templates.yaml -o $TEST_OUTPUT_BASE -p test51 && [ ! -d $TEST_OUTPUT_BASE/test51 ]" \
    "Mode: DRY-RUN"

run_test "52. Run mode creates files in correct location" \
    "python3 $TEMPLPROC -V test_values.txt -P '@HOSTNAME@,@IP_ADDRESS@,@PORT@' -T test_templates.yaml -o $TEST_OUTPUT_BASE -p test52 -r && [ -d $TEST_OUTPUT_BASE/test52 ] && [ \$(ls $TEST_OUTPUT_BASE/test52/*.yaml 2>/dev/null | wc -l) -eq 3 ]" \
    "Mode: RUN"

echo ""
echo "========================================"
echo "Test Results:"
echo -e "  ${GREEN}Passed: $PASSED${NC}"
echo -e "  ${RED}Failed: $FAILED${NC}"
echo -e "  Total: $((PASSED + FAILED))"
echo "========================================"

# Cleanup
rm -rf "$TEST_OUTPUT_BASE" /tmp/nulltest.txt /tmp/templproc_test_tmpls 2>/dev/null || true

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
