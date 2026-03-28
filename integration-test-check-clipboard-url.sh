#!/usr/bin/env bash

# Integration tests for check-clipboard-url.sh
# Tests actual clipboard reading and browser opening functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/check-clipboard-url.sh"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Parse command-line arguments
RUN_FLAKEY_TESTS=false
for arg in "$@"; do
	case "$arg" in
	--flakey-tests)
		RUN_FLAKEY_TESTS=true
		;;
	-h | --help)
		echo "Usage: $0 [OPTIONS]"
		echo ""
		echo "Options:"
		echo "  --flakey-tests  Run PowerShell clipboard tests (slow, expected to be flaky in some environments)"
		echo "  -h, --help      Show this help message"
		exit 0
		;;
	esac
done

# Set timeouts - use generous timeouts for flakey tests, strict for normal tests
if [ "$RUN_FLAKEY_TESTS" = true ]; then
	CLIPBOARD_TIMEOUT=60
	SCRIPT_TIMEOUT=30
else
	CLIPBOARD_TIMEOUT=5
	SCRIPT_TIMEOUT=3
fi

# ============= Helper Functions =============
test_result() {
	local test_name="$1"
	local result="$2"
	local message="$3"

	TESTS_RUN=$((TESTS_RUN + 1))

	case "$result" in
	"pass")
		printf "${GREEN}✓ PASS${NC}: %s\n" "$test_name"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		;;
	"fail")
		printf "${RED}✗ FAIL${NC}: %s - %s\n" "$test_name" "$message"
		TESTS_FAILED=$((TESTS_FAILED + 1))
		;;
	"skip")
		printf "${YELLOW}⊘ SKIP${NC}: %s - %s\n" "$test_name" "$message"
		TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
		;;
	esac
}

# Function to detect if running in WSL
is_wsl() {
	[[ -f /proc/version ]] && grep -q -i "microsoft\|wsl" /proc/version
	return $?
}

# Function to validate local directory path (same as main script)
is_valid_directory() {
	local path="$1"

	# Expand tilde to home directory if present
	if [[ $path =~ ^~ ]]; then
		path="${path/#~/$HOME}"
	fi

	# Check if directory exists and is readable
	[[ -d $path ]] && [[ -r $path ]]
	return $?
}

# Function to detect if running in WSL with PowerShell clipboard (slow/unreliable)
is_wsl_powershell() {
	is_wsl && command -v powershell.exe &>/dev/null
	return $?
}

# Check which clipboard tool is available
check_clipboard_tools() {
	if command -v xclip &>/dev/null; then
		echo "xclip"
		return 0
	elif command -v xsel &>/dev/null; then
		echo "xsel"
		return 0
	elif command -v pbpaste &>/dev/null; then
		echo "pbpaste"
		return 0
	elif is_wsl && command -v powershell.exe &>/dev/null; then
		echo "powershell.exe (WSL)"
		return 0
	else
		return 1
	fi
}

# Set clipboard content (requires xclip, xsel, or WSL PowerShell)
set_clipboard() {
	local content="$1"

	if command -v xclip &>/dev/null; then
		echo -n "$content" | xclip -selection clipboard
		return $?
	elif command -v xsel &>/dev/null; then
		echo -n "$content" | xsel --clipboard --input
		return $?
	elif is_wsl && command -v powershell.exe &>/dev/null; then
		# Use PowerShell to set clipboard in WSL
		powershell.exe -command "'$content' | Set-Clipboard" 2>/dev/null
		return $?
	else
		return 1
	fi
}

# Get clipboard content using the same logic as the main script
get_clipboard() {
	if command -v xclip &>/dev/null; then
		xclip -selection clipboard -o 2>/dev/null
	elif command -v xsel &>/dev/null; then
		xsel --clipboard --output 2>/dev/null
	elif command -v pbpaste &>/dev/null; then
		pbpaste 2>/dev/null
	elif is_wsl && command -v powershell.exe &>/dev/null; then
		powershell.exe -command "Get-Clipboard" 2>/dev/null | tr -d '\r'
	else
		return 1
	fi
}

# Check if browser launcher is available
check_browser_launcher() {
	if command -v xdg-open &>/dev/null; then
		echo "xdg-open"
		return 0
	elif command -v open &>/dev/null; then
		echo "open"
		return 0
	else
		return 1
	fi
}

# ============= Integration Tests =============
echo "${BLUE}=========================================="
echo "Integration Test Suite: check-clipboard-url.sh"
echo "==========================================${NC}"
echo ""

# Detect environment
if is_wsl; then
	if is_wsl_powershell; then
		printf "Environment: ${YELLOW}WSL (Windows Subsystem for Linux)${NC}\n"
		printf "Clipboard: ${YELLOW}PowerShell${NC}\n"
		if [ "$RUN_FLAKEY_TESTS" = true ]; then
			printf "Mode: ${YELLOW}Flakey tests ENABLED (long timeouts)${NC}\n"
			printf "  - Clipboard timeout: ${CLIPBOARD_TIMEOUT}s\n"
			printf "  - Script timeout: ${SCRIPT_TIMEOUT}s\n"
			SKIP_CLIPBOARD_TESTS=false # Run tests with extended timeouts
		else
			printf "Mode: ${YELLOW}Flakey tests DISABLED${NC}\n"
			SKIP_CLIPBOARD_TESTS=true # Skip clipboard tests in WSL with PowerShell by default
		fi
	else
		printf "Environment: ${YELLOW}WSL (Windows Subsystem for Linux)${NC}\n"
	fi
else
	printf "Environment: ${YELLOW}Native Linux/Unix${NC}\n"
fi
echo ""

# Test 1: Check clipboard tool availability
echo "${BLUE}--- Test 1: Clipboard Tool Availability ---${NC}"
CLIPBOARD_TOOL=$(check_clipboard_tools)
if [ $? -eq 0 ]; then
	test_result "Clipboard tool detection" "pass"
	printf "  Using: ${YELLOW}%s${NC}\n" "$CLIPBOARD_TOOL"
else
	test_result "Clipboard tool detection" "skip" "No clipboard tool available (xclip, xsel, pbpaste, or WSL PowerShell)"
	SKIP_CLIPBOARD_TESTS=true
fi

# Test 2: Check browser launcher availability
echo ""
echo "${BLUE}--- Test 2: Browser Launcher Availability ---${NC}"
BROWSER_LAUNCHER=$(check_browser_launcher)
if [ $? -eq 0 ]; then
	test_result "Browser launcher detection" "pass"
	printf "  Using: ${YELLOW}%s${NC}\n" "$BROWSER_LAUNCHER"
else
	test_result "Browser launcher detection" "skip" "No browser launcher available (xdg-open or open)"
	SKIP_BROWSER_TESTS=true
fi

# Test 3: Clipboard read/write cycle
echo ""
echo "${BLUE}--- Test 3: Clipboard Read/Write ---${NC}"
if [ "$SKIP_CLIPBOARD_TESTS" != "true" ]; then
	TEST_URL="https://www.github.com/test"

	# Use timeout to avoid hanging on slow PowerShell operations
	if timeout "$CLIPBOARD_TIMEOUT" set_clipboard "$TEST_URL" 2>/dev/null; then
		READ_URL=$(timeout "$CLIPBOARD_TIMEOUT" get_clipboard)
		if [ "$READ_URL" = "$TEST_URL" ]; then
			test_result "Clipboard write and read" "pass"
		else
			test_result "Clipboard write and read" "fail" "Expected: $TEST_URL, Got: $READ_URL"
		fi
	else
		test_result "Clipboard write and read" "skip" "Clipboard operation timed out (PowerShell may be slow)"
	fi
else
	test_result "Clipboard write and read" "skip" "Clipboard tools not available"
fi

# Test 4: Script detects empty clipboard
echo ""
echo "${BLUE}--- Test 4: Empty Clipboard Detection ---${NC}"
if [ "$SKIP_CLIPBOARD_TESTS" != "true" ]; then
	# Clear clipboard
	timeout "$CLIPBOARD_TIMEOUT" set_clipboard "" 2>/dev/null

	# Run script with 1 retry and 1 second wait, expecting failure
	output=$(timeout "$SCRIPT_TIMEOUT" "$MAIN_SCRIPT" --retry-count 1 --wait-time 1 2>&1)
	exit_code=$?

	if [ $exit_code -ne 0 ] && echo "$output" | grep -q "Clipboard is empty"; then
		test_result "Empty clipboard detection" "pass"
	else
		test_result "Empty clipboard detection" "fail" "Script didn't detect empty clipboard properly"
	fi
else
	test_result "Empty clipboard detection" "skip" "Clipboard tools not available"
fi

# Test 5: Script detects invalid URL
echo ""
echo "${BLUE}--- Test 5: Invalid URL Detection ---${NC}"
if [ "$SKIP_CLIPBOARD_TESTS" != "true" ]; then
	timeout "$CLIPBOARD_TIMEOUT" set_clipboard "invalid" 2>/dev/null

	# Run script with 1 retry and 1 second wait, expecting failure
	output=$(timeout "$SCRIPT_TIMEOUT" "$MAIN_SCRIPT" --retry-count 1 --wait-time 1 2>&1)
	exit_code=$?

	if [ $exit_code -ne 0 ] && echo "$output" | grep -q "Invalid URL"; then
		test_result "Invalid URL detection" "pass"
	else
		test_result "Invalid URL detection" "fail" "Script didn't detect invalid URL"
	fi
else
	test_result "Invalid URL detection" "skip" "Clipboard tools not available"
fi

# Test 6: Script accepts valid HTTPS URL
echo ""
echo "${BLUE}--- Test 6: Valid HTTPS URL Acceptance ---${NC}"
if [ "$SKIP_CLIPBOARD_TESTS" != "true" ] && [ "$SKIP_BROWSER_TESTS" != "true" ]; then
	timeout "$CLIPBOARD_TIMEOUT" set_clipboard "https://www.example.com" 2>/dev/null

	# Mock the browser launcher to avoid actually opening a browser
	# Create a temporary wrapper script
	TEMP_DIR=$(mktemp -d)
	FAKE_BROWSER="$TEMP_DIR/fake-browser"

	if [ "$BROWSER_LAUNCHER" = "xdg-open" ]; then
		cat >"$FAKE_BROWSER" <<'EOF'
#!/bin/bash
echo "Browser would open: $1" > /tmp/browser-call.log
exit 0
EOF
	elif [ "$BROWSER_LAUNCHER" = "open" ]; then
		cat >"$FAKE_BROWSER" <<'EOF'
#!/bin/bash
echo "Browser would open: $1" > /tmp/browser-call.log
exit 0
EOF
	fi

	chmod +x "$FAKE_BROWSER"

	# Temporarily modify PATH to use fake browser
	ORIGINAL_PATH="$PATH"

	if [ "$BROWSER_LAUNCHER" = "xdg-open" ]; then
		XDGOPEN_REAL=$(command -v xdg-open)
		# Create wrapper that calls our fake
		ln -sf "$FAKE_BROWSER" "$TEMP_DIR/xdg-open" 2>/dev/null
		PATH="$TEMP_DIR:$PATH"

		timeout "$SCRIPT_TIMEOUT" "$MAIN_SCRIPT" --retry-count 1 --wait-time 1 &>/dev/null
		result=$?

		PATH="$ORIGINAL_PATH"
		rm -rf "$TEMP_DIR"

		if [ $result -eq 0 ]; then
			test_result "Valid HTTPS URL acceptance" "pass"
		else
			test_result "Valid HTTPS URL acceptance" "fail" "Script didn't accept valid HTTPS URL"
		fi
	else
		test_result "Valid HTTPS URL acceptance" "skip" "Test requires xdg-open (for safer browser mocking)"
		rm -rf "$TEMP_DIR"
	fi
else
	test_result "Valid HTTPS URL acceptance" "skip" "Clipboard or browser tools not available"
fi

# Test 7: Script accepts valid HTTP URL
echo ""
echo "${BLUE}--- Test 7: Valid HTTP URL Acceptance ---${NC}"
if [ "$SKIP_CLIPBOARD_TESTS" != "true" ] && [ "$SKIP_BROWSER_TESTS" != "true" ]; then
	timeout "$CLIPBOARD_TIMEOUT" set_clipboard "http://localhost:8080" 2>/dev/null

	# Similar test to Test 6
	TEMP_DIR=$(mktemp -d)
	FAKE_BROWSER="$TEMP_DIR/fake-browser"

	cat >"$FAKE_BROWSER" <<'EOF'
#!/bin/bash
exit 0
EOF

	chmod +x "$FAKE_BROWSER"

	if [ "$BROWSER_LAUNCHER" = "xdg-open" ]; then
		ln -sf "$FAKE_BROWSER" "$TEMP_DIR/xdg-open" 2>/dev/null
		ORIGINAL_PATH="$PATH"
		PATH="$TEMP_DIR:$PATH"

		timeout "$SCRIPT_TIMEOUT" "$MAIN_SCRIPT" --retry-count 1 --wait-time 1 &>/dev/null
		result=$?

		PATH="$ORIGINAL_PATH"
		rm -rf "$TEMP_DIR"

		if [ $result -eq 0 ]; then
			test_result "Valid HTTP URL acceptance" "pass"
		else
			test_result "Valid HTTP URL acceptance" "fail" "Script didn't accept valid HTTP URL"
		fi
	else
		test_result "Valid HTTP URL acceptance" "skip" "Test requires xdg-open"
		rm -rf "$TEMP_DIR"
	fi
else
	test_result "Valid HTTP URL acceptance" "skip" "Clipboard or browser tools not available"
fi

# Test 8: Script accepts domain without protocol
echo ""
echo "${BLUE}--- Test 8: Domain Without Protocol Acceptance ---${NC}"
if [ "$SKIP_CLIPBOARD_TESTS" != "true" ] && [ "$SKIP_BROWSER_TESTS" != "true" ]; then
	timeout "$CLIPBOARD_TIMEOUT" set_clipboard "www.example.com" 2>/dev/null

	TEMP_DIR=$(mktemp -d)
	FAKE_BROWSER="$TEMP_DIR/fake-browser"

	cat >"$FAKE_BROWSER" <<'EOF'
#!/bin/bash
exit 0
EOF

	chmod +x "$FAKE_BROWSER"

	if [ "$BROWSER_LAUNCHER" = "xdg-open" ]; then
		ln -sf "$FAKE_BROWSER" "$TEMP_DIR/xdg-open" 2>/dev/null
		ORIGINAL_PATH="$PATH"
		PATH="$TEMP_DIR:$PATH"

		timeout "$SCRIPT_TIMEOUT" "$MAIN_SCRIPT" --retry-count 1 --wait-time 1 &>/dev/null
		result=$?

		PATH="$ORIGINAL_PATH"
		rm -rf "$TEMP_DIR"

		if [ $result -eq 0 ]; then
			test_result "Domain without protocol acceptance" "pass"
		else
			test_result "Domain without protocol acceptance" "fail" "Script didn't accept domain without protocol"
		fi
	else
		test_result "Domain without protocol acceptance" "skip" "Test requires xdg-open"
		rm -rf "$TEMP_DIR"
	fi
else
	test_result "Domain without protocol acceptance" "skip" "Clipboard or browser tools not available"
fi

# Test 9: Script handles retry logic
echo ""
echo "${BLUE}--- Test 9: Retry Logic ---${NC}"
if [ "$SKIP_CLIPBOARD_TESTS" != "true" ]; then
	# Put invalid URL in clipboard
	timeout "$CLIPBOARD_TIMEOUT" set_clipboard "invalid" 2>/dev/null

	# Run with 3 retries, 1 second wait
	START_TIME=$(date +%s)
	timeout "$SCRIPT_TIMEOUT" "$MAIN_SCRIPT" --retry-count 3 --wait-time 1 2>&1 >/dev/null
	END_TIME=$(date +%s)
	ELAPSED=$((END_TIME - START_TIME))

	# With 3 retries and 1 second wait between, should take at least 2 seconds
	# (retry 1, wait 1s, retry 2, wait 1s, retry 3, no wait)
	if [ $ELAPSED -ge 2 ]; then
		test_result "Retry logic with timing" "pass"
		printf "  Elapsed time: ${YELLOW}%ds${NC} (expected: ≥2s)\n" "$ELAPSED"
	else
		test_result "Retry logic with timing" "fail" "Expected at least 2s, got ${ELAPSED}s"
	fi
else
	test_result "Retry logic with timing" "skip" "Clipboard tools not available"
fi

# Test 10: Script handles infinite retry with timeout
echo ""
echo "${BLUE}--- Test 10: Infinite Retry Mode ---${NC}"
if [ "$SKIP_CLIPBOARD_TESTS" != "true" ]; then
	timeout "$CLIPBOARD_TIMEOUT" set_clipboard "invalid" 2>/dev/null

	# Run in infinite mode but timeout after 2 seconds (or longer for flakey tests)
	output=$(timeout "$SCRIPT_TIMEOUT" "$MAIN_SCRIPT" --retry-count -1 --wait-time 1 2>&1)
	exit_code=$?

	# Should be interrupted by timeout (exit code 124)
	if [ $exit_code -eq 124 ] && echo "$output" | grep -q "Warning: Running in infinite loop mode"; then
		test_result "Infinite retry mode" "pass"
	else
		test_result "Infinite retry mode" "fail" "Exit code: $exit_code (expected 124)"
	fi
else
	test_result "Infinite retry mode" "skip" "Clipboard tools not available"
fi

# Test 11: Local mode with valid directory
echo ""
echo "${BLUE}--- Test 11: Local Mode with Valid Directory ---${NC}"
if [ "$SKIP_CLIPBOARD_TESTS" != "true" ] && [ "$SKIP_BROWSER_TESTS" != "true" ]; then
	timeout "$CLIPBOARD_TIMEOUT" set_clipboard "/tmp" 2>/dev/null

	# Run in local mode with 1 attempt - should accept /tmp as valid directory
	output=$(timeout "$SCRIPT_TIMEOUT" "$MAIN_SCRIPT" --local --retry-count 1 --wait-time 1 2>&1)
	exit_code=$?

	if [ $exit_code -eq 0 ] && echo "$output" | grep -q "Valid directory found"; then
		test_result "Local mode accepts valid directory" "pass"
	else
		test_result "Local mode accepts valid directory" "fail" "Expected to accept /tmp directory"
	fi
else
	test_result "Local mode accepts valid directory" "skip" "Clipboard or browser tools not available"
fi

# Test 12: Local mode with invalid directory
echo ""
echo "${BLUE}--- Test 12: Local Mode with Invalid Directory ---${NC}"
if [ "$SKIP_CLIPBOARD_TESTS" != "true" ]; then
	timeout "$CLIPBOARD_TIMEOUT" set_clipboard "/nonexistent/directory/path" 2>/dev/null

	# Run in local mode - should reject invalid directory
	output=$(timeout "$SCRIPT_TIMEOUT" "$MAIN_SCRIPT" --local --retry-count 1 --wait-time 1 2>&1)
	exit_code=$?

	if [ $exit_code -ne 0 ] && echo "$output" | grep -q "Invalid directory path"; then
		test_result "Local mode rejects invalid directory" "pass"
	else
		test_result "Local mode rejects invalid directory" "fail" "Should reject /nonexistent/directory/path"
	fi
else
	test_result "Local mode rejects invalid directory" "skip" "Clipboard tools not available"
fi

# Test 13: Local mode with home directory expansion
echo ""
echo "${BLUE}--- Test 13: Local Mode with Tilde Expansion ---${NC}"
if [ "$SKIP_CLIPBOARD_TESTS" != "true" ] && [ "$SKIP_BROWSER_TESTS" != "true" ]; then
	timeout "$CLIPBOARD_TIMEOUT" set_clipboard "~" 2>/dev/null

	# Run in local mode - should expand ~ to home directory
	output=$(timeout "$SCRIPT_TIMEOUT" "$MAIN_SCRIPT" --local --retry-count 1 --wait-time 1 2>&1)
	exit_code=$?

	if [ $exit_code -eq 0 ] && echo "$output" | grep -q "Valid directory found"; then
		test_result "Local mode expands tilde to home" "pass"
	else
		test_result "Local mode expands tilde to home" "fail" "Should expand ~ to home directory"
	fi
else
	test_result "Local mode expands tilde to home" "skip" "Clipboard or browser tools not available"
fi

# Test 14: Short form -l flag with local mode
echo ""
echo "${BLUE}--- Test 14: Local Mode with Short Flag (-l) ---${NC}"
if [ "$SKIP_CLIPBOARD_TESTS" != "true" ]; then
	timeout "$CLIPBOARD_TIMEOUT" set_clipboard "/tmp" 2>/dev/null

	# Run in local mode using -l short flag
	output=$(timeout "$SCRIPT_TIMEOUT" "$MAIN_SCRIPT" -l --retry-count 1 --wait-time 1 2>&1)
	exit_code=$?

	if [ $exit_code -eq 0 ] && echo "$output" | grep -q "Valid directory found"; then
		test_result "Short -l flag works for local mode" "pass"
	else
		test_result "Short -l flag works for local mode" "fail" "Short flag -l should work"
	fi
else
	test_result "Short -l flag works for local mode" "skip" "Clipboard or browser tools not available"
fi

# Print summary
echo ""
echo "${BLUE}=========================================="
echo "Integration Test Summary"
echo "==========================================${NC}"
printf "Tests run:     %s\n" "$TESTS_RUN"
printf "Tests passed:  ${GREEN}%s${NC}\n" "$TESTS_PASSED"
printf "Tests failed:  ${RED}%s${NC}\n" "$TESTS_FAILED"
printf "Tests skipped: ${YELLOW}%s${NC}\n" "$TESTS_SKIPPED"
echo "${BLUE}==========================================${NC}"

if [ $TESTS_FAILED -eq 0 ] && [ $TESTS_PASSED -gt 0 ]; then
	printf "${GREEN}Integration tests completed successfully!${NC}\n"
	exit 0
elif [ $TESTS_SKIPPED -eq $TESTS_RUN ]; then
	printf "${YELLOW}All tests skipped - clipboard/browser tools not available${NC}\n"
	exit 0
else
	printf "${RED}Some integration tests failed.${NC}\n"
	exit 1
fi
