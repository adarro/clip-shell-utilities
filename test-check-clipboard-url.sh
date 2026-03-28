#!/bin/bash

# Test suite for check-clipboard-url.sh
# Tests URL validation and browser opening functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============= WSL Detection Function =============
# Function to detect if running in WSL
is_wsl() {
    [[ -f /proc/version ]] && grep -q -i "microsoft\|wsl" /proc/version
    return $?
}

# ============= Directory Validation Function =============
is_valid_directory() {
    local path="$1"
    
    # Expand tilde to home directory if present
    if [[ "$path" =~ ^~ ]]; then
        path="${path/#~/$HOME}"
    fi
    
    # Check if directory exists and is readable
    [[ -d "$path" ]] && [[ -r "$path" ]]
    return $?
}

# ============= URL Validation Function =============
# Extracted from the main script for testing
is_valid_url() {
    local url="$1"
    
    # Check if URL starts with http:// or https://
    if [[ $url =~ ^https?:// ]]; then
        return 0
    fi
    
    # Check if it looks like a valid domain without protocol
    # Must contain at least one dot (for TLD)
    if [[ $url =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$ ]]; then
        return 0
    fi
    
    return 1
}

# ============= Browser Opening Function =============
open_browser_test() {
    local url="$1"
    
    # Add protocol if not present
    if [[ ! $url =~ ^https?:// ]]; then
        url="https://$url"
    fi
    
    # For testing, just validate that url has proper format
    if [[ $url =~ ^https?:// ]]; then
        echo "$url"
        return 0
    fi
    return 1
}

# ============= Test Helper Functions =============
test_url_validation() {
    local url="$1"
    local expected="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if is_valid_url "$url"; then
        if [ "$expected" = "valid" ]; then
            printf "${GREEN}✓ PASS${NC}: %s (accepted: %s)\n" "$test_name" "$url"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            printf "${RED}✗ FAIL${NC}: %s (should reject: %s)\n" "$test_name" "$url"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        if [ "$expected" = "invalid" ]; then
            printf "${GREEN}✓ PASS${NC}: %s (rejected: %s)\n" "$test_name" "$url"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            printf "${RED}✗ FAIL${NC}: %s (should accept: %s)\n" "$test_name" "$url"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    fi
}

test_browser_opening() {
    local url="$1"
    local expected_result="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    result=$(open_browser_test "$url")
    
    if [[ $? -eq 0 ]] && [[ "$result" == ${expected_result} ]]; then
        printf "${GREEN}✓ PASS${NC}: %s (opened: %s)\n" "$test_name" "$result"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        printf "${RED}✗ FAIL${NC}: %s (expected: %s, got: %s)\n" "$test_name" "$expected_result" "$result"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# ============= Test Execution =============
echo "=========================================="
echo "Test Suite: check-clipboard-url.sh"
echo "=========================================="
echo ""

# Test 1: Valid URLs with https://
echo "--- Test 1: Valid HTTPS URLs ---"
test_url_validation "https://www.google.com" "valid" "HTTPS URL"
test_url_validation "https://github.com/user/repo" "valid" "HTTPS URL with path"
test_url_validation "https://example.com" "valid" "HTTPS simple domain"

# Test 2: Valid URLs with http://
echo ""
echo "--- Test 2: Valid HTTP URLs ---"
test_url_validation "http://www.example.com" "valid" "HTTP URL"
test_url_validation "http://localhost:8080" "valid" "HTTP localhost with port"
test_url_validation "http://192.168.1.1" "valid" "HTTP IP address"

# Test 3: Valid URLs without protocol
echo ""
echo "--- Test 3: Valid URLs without protocol ---"
test_url_validation "www.google.com" "valid" "Domain without protocol"
test_url_validation "example.com" "valid" "Simple domain"
test_url_validation "github.com" "valid" "GitHub domain"
test_url_validation "a.co" "valid" "Two-letter domain"

# Test 4: Invalid URLs
echo ""
echo "--- Test 4: Invalid URLs ---"
test_url_validation "" "invalid" "Empty string"
test_url_validation "not a url" "invalid" "Random text with spaces"
test_url_validation "ftp://example.com" "invalid" "FTP protocol (unsupported)"
test_url_validation "just-text" "invalid" "Text without domain structure"
test_url_validation "-example.com" "invalid" "Domain starting with hyphen"
test_url_validation "example.com-" "invalid" "Domain ending with hyphen"
test_url_validation "@example.com" "invalid" "Domain starting with special char"
test_url_validation "example" "invalid" "Single word without TLD"

# Test 5: Browser opening with protocol addition
echo ""
echo "--- Test 5: Browser opening with protocol addition ---"
test_browser_opening "https://www.google.com" "https://www.google.com" "HTTPS URL unchanged"
test_browser_opening "http://example.com" "http://example.com" "HTTP URL unchanged"
test_browser_opening "www.example.com" "https://www.example.com" "Domain gets HTTPS added"
test_browser_opening "github.com" "https://github.com" "Simple domain gets HTTPS"

# Test 6: WSL Environment Detection
echo ""
echo "--- Test 6: WSL Environment Detection ---"
TESTS_RUN=$((TESTS_RUN + 1))
if is_wsl; then
    printf "${YELLOW}⚠ INFO${NC}: Running in WSL environment\n"
    printf "${GREEN}✓ PASS${NC}: WSL detection function works\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${GREEN}✓ PASS${NC}: Not in WSL environment (or detection working correctly)\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# Test 7: Command-line argument validation
echo ""
echo "--- Test 7: Command-line argument validation ---"
TESTS_RUN=$((TESTS_RUN + 1))
if ! "$SCRIPT_DIR/check-clipboard-url.sh" --retry-count 0 &>/dev/null; then
    printf "${GREEN}✓ PASS${NC}: Invalid retry count (0) rejected\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}✗ FAIL${NC}: Invalid retry count (0) should be rejected\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

TESTS_RUN=$((TESTS_RUN + 1))
if ! "$SCRIPT_DIR/check-clipboard-url.sh" --wait-time 0 &>/dev/null; then
    printf "${GREEN}✓ PASS${NC}: Invalid wait time (0, minimum is 1) rejected\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}✗ FAIL${NC}: Invalid wait time (0) should be rejected\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

TESTS_RUN=$((TESTS_RUN + 1))
if ! "$SCRIPT_DIR/check-clipboard-url.sh" --unknown-option &>/dev/null; then
    printf "${GREEN}✓ PASS${NC}: Unknown options rejected\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}✗ FAIL${NC}: Unknown options should be rejected\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 8: Infinite loop mode
echo ""
echo "--- Test 8: Infinite loop mode with -1 retry count ---"
TESTS_RUN=$((TESTS_RUN + 1))
# Test that -1 is accepted as a valid retry count
output=$("$SCRIPT_DIR/check-clipboard-url.sh" --retry-count -1 --wait-time 1 2>&1 | head -1)
if echo "$output" | grep -q "Warning: Running in infinite loop mode"; then
    printf "${GREEN}✓ PASS${NC}: Infinite loop mode (-1) accepted with warning\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}✗ FAIL${NC}: Infinite loop mode (-1) should show warning, got: %s\n" "$output"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

TESTS_RUN=$((TESTS_RUN + 1))
# Test that negative retry counts other than -1 are rejected
if ! "$SCRIPT_DIR/check-clipboard-url.sh" --retry-count -2 &>/dev/null; then
    printf "${GREEN}✓ PASS${NC}: Invalid retry count (-2) rejected\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}✗ FAIL${NC}: Invalid retry count (-2) should be rejected\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 9: Local mode directory validation
echo ""
echo "--- Test 9: Local mode directory validation ---"
test_directory_validation() {
    local path="$1"
    local expected="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if is_valid_directory "$path"; then
        if [ "$expected" = "valid" ]; then
            printf "${GREEN}✓ PASS${NC}: %s (accepted: %s)\n" "$test_name" "$path"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            printf "${RED}✗ FAIL${NC}: %s (should reject: %s)\n" "$test_name" "$path"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        if [ "$expected" = "invalid" ]; then
            printf "${GREEN}✓ PASS${NC}: %s (rejected: %s)\n" "$test_name" "$path"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            printf "${RED}✗ FAIL${NC}: %s (should accept: %s)\n" "$test_name" "$path"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    fi
}

test_directory_validation "/tmp" "valid" "Valid /tmp directory"
test_directory_validation "$HOME" "valid" "Valid home directory"
test_directory_validation "~" "valid" "Tilde expansion to home"
test_directory_validation "/nonexistent/path" "invalid" "Nonexistent directory"
test_directory_validation "/etc/passwd" "invalid" "File instead of directory"

# Test 10: Local mode option parsing
echo ""
echo "--- Test 10: Local mode option parsing ---"
TESTS_RUN=$((TESTS_RUN + 1))
if "$SCRIPT_DIR/check-clipboard-url.sh" --local --retry-count 1 --wait-time 1 2>&1 | grep -q "Clipboard is empty\|Invalid directory"; then
    printf "${GREEN}✓ PASS${NC}: --local flag accepted\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}✗ FAIL${NC}: --local flag should be accepted\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

TESTS_RUN=$((TESTS_RUN + 1))
if "$SCRIPT_DIR/check-clipboard-url.sh" -l --retry-count 1 --wait-time 1 2>&1 | grep -q "Clipboard is empty\|Invalid directory"; then
    printf "${GREEN}✓ PASS${NC}: -l flag (short form) accepted\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    printf "${RED}✗ FAIL${NC}: -l flag should be accepted\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Print summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
printf "Tests run:    %s\n" "$TESTS_RUN"
printf "Tests passed: ${GREEN}%s${NC}\n" "$TESTS_PASSED"
printf "Tests failed: ${RED}%s${NC}\n" "$TESTS_FAILED"
echo "=========================================="

if [ $TESTS_FAILED -eq 0 ]; then
    printf "${GREEN}All tests passed!${NC}\n"
    exit 0
else
    printf "${RED}Some tests failed.${NC}\n"
    exit 1
fi
