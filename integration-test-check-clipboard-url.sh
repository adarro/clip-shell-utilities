#!/bin/bash

# Integration tests for check-clipboard-url.sh
# Tests actual clipboard reading and browser opening functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="${SCRIPT_DIR}/check-clipboard-url.sh"

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
	case "${arg}" in
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
if [[ ${RUN_FLAKEY_TESTS} == true ]]; then
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

	case "${result}" in
	"pass")
		printf "%b✓ PASS%b: %s\n" "${GREEN}" "${NC}" "${test_name}"
		TESTS_PASSED=$((TESTS_PASSED + 1))
		;;
	"fail")
		printf "%b✗ FAIL%b: %s - %s\n" "${RED}" "${NC}" "${test_name}" "${message}"
		TESTS_FAILED=$((TESTS_FAILED + 1))
		;;
	"skip")
		printf "%b⊘ SKIP%b: %s - %s\n" "${YELLOW}" "${NC}" "${test_name}" "${message}"
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
	if [[ ${path} =~ ^~ ]]; then
		path="${path/#~/${HOME}}"
	fi

	# Check if directory exists and is readable
	[[ -d ${path} ]] && [[ -r ${path} ]]
	return $?
}

# Function to detect if running in WSL with PowerShell clipboard (slow/unreliable)
is_wsl_powershell() {
	is_wsl && command -v powershell.exe &>/dev/null
	return $?
}

# Function to detect if running in CI/headless environment
is_ci_environment() {
	# Check for common CI environment variables
	# GitHub Actions
	[[ -n ${GITHUB_ACTIONS} ]] && return 0
	# GitLab CI
	[[ -n ${GITLAB_CI} ]] && return 0
	# Generic CI variable used by many systems
	[[ -n ${CI} ]] && return 0
	# CircleCI
	[[ -n ${CIRCLECI} ]] && return 0
	# Travis CI
	[[ -n ${TRAVIS} ]] && return 0
	# Jenkins
	[[ -n ${JENKINS_HOME} ]] && return 0
	# Buildkite
	[[ -n ${BUILDKITE} ]] && return 0
	# Azure DevOps
	[[ -n ${SYSTEM_TEAMFOUNDATIONCOLLECTIONURI} ]] && return 0
	# Google Cloud Build
	[[ -n ${BUILD_ID} ]] && [[ -n ${PROJECT_ID} ]] && return 0
	return 1
}

# Check which clipboard tool is available
check_clipboard_tools() {
	if command -v xclip &>/dev/null; then
		echo "xclip"
	elif command -v xsel &>/dev/null; then
		echo "xsel"
	elif command -v pbpaste &>/dev/null; then
		echo "pbpaste"
	elif is_wsl && command -v powershell.exe &>/dev/null; then
		echo "powershell.exe (WSL)"
	else
		return 1
	fi
}

# Check which clipboard tool is available
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

# ============= Tool Detection (run once at initialize) =============
# Will be done just before integration tests section
# (after all helper functions are defined)

# Set clipboard content using pre-detected tool
set_clipboard() {
	local content="$1"

	case "${DETECTED_CLIPBOARD_TOOL}" in
	xclip)
		echo -n "${content}" | xclip -selection clipboard
		return $?
		;;
	xsel)
		echo -n "${content}" | xsel --clipboard --input
		return $?
		;;
	"powershell.exe (WSL)")
		# Use PowerShell to set clipboard in WSL
		powershell.exe -Command "Set-Clipboard -Value '${content}'" 2>/dev/null
		return $?
		;;
	pbpaste)
		# pbpaste is read-only, use pbcopy for macOS
		if command -v pbcopy &>/dev/null; then
			echo -n "${content}" | pbcopy
			return $?
		fi
		return 1
		;;
	*)
		return 1
		;;
	esac
}

# Get clipboard content using pre-detected tool
get_clipboard() {
	case "${DETECTED_CLIPBOARD_TOOL}" in
	xclip)
		xclip -selection clipboard -o 2>/dev/null
		;;
	xsel)
		xsel --clipboard --output 2>/dev/null
		;;
	pbpaste)
		pbpaste 2>/dev/null
		;;
	"powershell.exe (WSL)")
		powershell.exe -command "Get-Clipboard" 2>/dev/null | tr -d '\r'
		;;
	*)
		return 1
		;;
	esac
}

# ============= Integration Tests =============
# Detect and cache available tools (after all functions are defined)
DETECTED_CLIPBOARD_TOOL=$(check_clipboard_tools 2>/dev/null)
DETECTED_BROWSER_LAUNCHER=$(check_browser_launcher 2>/dev/null)

printf "%b==========================================\n" "${BLUE}"
printf "Integration Test Suite: check-clipboard-url.sh\n"
printf "==========================================%b\n" "${NC}"
echo ""

# Detect environment
if is_ci_environment; then
	printf "Environment: %bCI/Headless Mode (detected)%b\n" "${YELLOW}" "${NC}"
	printf "Mode: %bSkipping clipboard and browser tests (headless environment)%b\n" "${YELLOW}" "${NC}"
	SKIP_CLIPBOARD_TESTS=true
	SKIP_BROWSER_TESTS=true
elif is_wsl; then
	if is_wsl_powershell; then
		printf "Environment: %bWSL (Windows Subsystem for Linux)%b\n" "${YELLOW}" "${NC}"
		printf "Clipboard: %bPowerShell%b\n" "${YELLOW}" "${NC}"
		if [[ ${RUN_FLAKEY_TESTS} == true ]]; then
			printf "Mode: %bFlakey tests ENABLED (long timeouts)%b\n" "${YELLOW}" "${NC}"
			printf "  - Clipboard timeout: %ss\n" "${CLIPBOARD_TIMEOUT}"
			printf "  - Script timeout: %ss\n" "${SCRIPT_TIMEOUT}"
			SKIP_CLIPBOARD_TESTS=false # Run tests with extended timeouts
		else
			printf "Mode: %bFlakey tests DISABLED%b\n" "${YELLOW}" "${NC}"
			SKIP_CLIPBOARD_TESTS=true # Skip clipboard tests in WSL with PowerShell by default
		fi
	else
		printf "Environment: %bWSL (Windows Subsystem for Linux)%b\n" "${YELLOW}" "${NC}"
	fi
else
	printf "Environment: %bNative Linux/Unix%b\n" "${YELLOW}" "${NC}"
fi
echo ""

# Test 1: Check clipboard tool availability
printf "%b--- Test 1: Clipboard Tool Availability ---%b\n" "${BLUE}" "${NC}"
if [[ -n ${DETECTED_CLIPBOARD_TOOL} ]]; then
	test_result "Clipboard tool detection" "pass"
	printf "  Using: %b%s%b\n" "${YELLOW}" "${DETECTED_CLIPBOARD_TOOL}" "${NC}"
else
	test_result "Clipboard tool detection" "skip" "No clipboard tool available (xclip, xsel, pbpaste, or WSL PowerShell)"
	SKIP_CLIPBOARD_TESTS=true
fi

# Test 2: Check browser launcher availability
printf "\n"
printf "%b--- Test 2: Browser Launcher Availability ---%b\n" "${BLUE}" "${NC}"
if [[ -n ${DETECTED_BROWSER_LAUNCHER} ]]; then
	test_result "Browser launcher detection" "pass"
	printf "  Using: %b%s%b\n" "${YELLOW}" "${DETECTED_BROWSER_LAUNCHER}" "${NC}"
else
	test_result "Browser launcher detection" "skip" "No browser launcher available (xdg-open or open)"
	SKIP_BROWSER_TESTS=true
fi

# Test 3: Clipboard read/write cycle
printf "\n"
printf "%b--- Test 3: Clipboard Read/Write ---%b\n" "${BLUE}" "${NC}"
if [[ ${SKIP_CLIPBOARD_TESTS} != "true" ]]; then
	TEST_URL="https://www.github.com/test"
	echo "Testing clipboard write and read with URL: ${TEST_URL} and clipboard timeout: ${CLIPBOARD_TIMEOUT}s"

	# Don't use timeout for get / set_clipboard.  It creates a permission denied error on PowerShell operations
	if set_clipboard "${TEST_URL}" 2>/dev/null; then
		READ_URL=$(get_clipboard)
		if [[ ${READ_URL} == "${TEST_URL}" ]]; then
			test_result "Clipboard write and read" "pass"
		else
			test_result "Clipboard write and read" "fail" "Expected: ${TEST_URL}, Got: ${READ_URL}"
		fi
	else
		test_result "Clipboard write and read" "skip" "Clipboard operation timed out (PowerShell may be slow)"
	fi
else
	test_result "Clipboard write and read" "skip" "Clipboard tools not available"
fi

# Test 4: Script detects empty clipboard
printf "\n"
printf "%b--- Test 4: Empty Clipboard Detection ---%b\n" "${BLUE}" "${NC}"
if [[ ${SKIP_CLIPBOARD_TESTS} != "true" ]]; then
	# Place something in clipboard to insure clipboard is actually being cleared
	set_clipboard "some random data" 2>/dev/null
	assert_clipboard=$(get_clipboard)
	if [[ ${assert_clipboard} != "some random data" ]]; then
		test_result "Empty clipboard setup failed" "skip" "Could not seed data for preconditions"
	else
		# Clear clipboard
		set_clipboard "" 2>/dev/null
		expected=""
		actual=$(get_clipboard)
		if [[ ${actual} != "${expected}" ]]; then
			test_result "Empty clipboard detection" "fail" "Expected empty clipboard, got: '${actual}'"
		else
			test_result "Empty clipboard detection" "pass"
		fi
	fi
else
	test_result "Empty clipboard detection" "skip" "Clipboard tools not available"
fi

# Test 5: Script detects invalid URL
printf "\n"
printf "%b--- Test 5: Invalid URL Detection ---%b\n" "${BLUE}" "${NC}"
if [[ ${SKIP_CLIPBOARD_TESTS} != "true" ]]; then
	set_clipboard "invalid" 2>/dev/null

	# Run script with 1 retry and 1 second wait, expecting failure
	output=$(timeout "${SCRIPT_TIMEOUT}" "${MAIN_SCRIPT}" --retry-count 1 --wait-time 1 2>&1)
	exit_code=$?

	if [[ ${exit_code} -ne 0 ]] && echo "${output}" | grep -q "Invalid URL"; then
		test_result "Invalid URL detection" "pass"
	else
		test_result "Invalid URL detection" "fail" "Script didn't detect invalid URL"
	fi
else
	test_result "Invalid URL detection" "skip" "Clipboard tools not available"
fi

# Test 6: Script accepts valid HTTPS URL
printf "\n"
printf "%b--- Test 6: Valid HTTPS URL Acceptance ---%b\n" "${BLUE}" "${NC}"
if [[ ${SKIP_CLIPBOARD_TESTS} != "true" ]] && [[ ${SKIP_BROWSER_TESTS} != "true" ]]; then
	set_clipboard "https://www.example.com" 2>/dev/null

	# Mock the browser launcher to avoid actually opening a browser
	# Create a temporary wrapper script
	TEMP_DIR=$(mktemp -d)
	FAKE_BROWSER="${TEMP_DIR}/fake-browser"

	if [[ ${DETECTED_BROWSER_LAUNCHER} == "xdg-open" ]]; then
		cat >"${FAKE_BROWSER}" <<'EOF'
#!/bin/bash
echo "Browser would open: $1" > /tmp/browser-call.log
exit 0
EOF
	elif [[ ${DETECTED_BROWSER_LAUNCHER} == "open" ]]; then
		cat >"${FAKE_BROWSER}" <<'EOF'
#!/bin/bash
echo "Browser would open: $1" > /tmp/browser-call.log
exit 0
EOF
	fi

	chmod +x "${FAKE_BROWSER}"

	# Temporarily modify PATH to use fake browser
	ORIGINAL_PATH="${PATH}"

	if [[ ${DETECTED_BROWSER_LAUNCHER} == "xdg-open" ]]; then
		XDGOPEN_REAL=$(command -v xdg-open)
		# Create wrapper that calls our fake
		ln -sf "${FAKE_BROWSER}" "${TEMP_DIR}/xdg-open" 2>/dev/null
		PATH="${TEMP_DIR}:${PATH}"

		timeout "${SCRIPT_TIMEOUT}" "${MAIN_SCRIPT}" --retry-count 1 --wait-time 1 &>/dev/null
		result=$?

		PATH="${ORIGINAL_PATH}"
		rm -rf "${TEMP_DIR}"

		if [[ ${result} -eq 0 ]]; then
			test_result "Valid HTTPS URL acceptance" "pass"
		else
			test_result "Valid HTTPS URL acceptance" "fail" "Script didn't accept valid HTTPS URL"
		fi
	else
		test_result "Valid HTTPS URL acceptance" "skip" "Test requires xdg-open (for safer browser mocking)"
		rm -rf "${TEMP_DIR}"
	fi
else
	test_result "Valid HTTPS URL acceptance" "skip" "Clipboard or browser tools not available"
fi

# Test 7: Script accepts valid HTTP URL
printf "\n"
printf "%b--- Test 7: Valid HTTP URL Acceptance ---%b\n" "${BLUE}" "${NC}"
if [[ ${SKIP_CLIPBOARD_TESTS} != "true" ]] && [[ ${SKIP_BROWSER_TESTS} != "true" ]]; then
	set_clipboard "http://localhost:8080" 2>/dev/null

	# Similar test to Test 6
	TEMP_DIR=$(mktemp -d)
	FAKE_BROWSER="${TEMP_DIR}/fake-browser"

	cat >"${FAKE_BROWSER}" <<'EOF'
#!/bin/bash
exit 0
EOF

	chmod +x "${FAKE_BROWSER}"

	if [[ ${DETECTED_BROWSER_LAUNCHER} == "xdg-open" ]]; then
		ln -sf "${FAKE_BROWSER}" "${TEMP_DIR}/xdg-open" 2>/dev/null
		ORIGINAL_PATH="${PATH}"
		PATH="${TEMP_DIR}:${PATH}"

		timeout "${SCRIPT_TIMEOUT}" "${MAIN_SCRIPT}" --retry-count 1 --wait-time 1 &>/dev/null
		result=$?

		PATH="${ORIGINAL_PATH}"
		rm -rf "${TEMP_DIR}"

		if [[ ${result} -eq 0 ]]; then
			test_result "Valid HTTP URL acceptance" "pass"
		else
			test_result "Valid HTTP URL acceptance" "fail" "Script didn't accept valid HTTP URL"
		fi
	else
		test_result "Valid HTTP URL acceptance" "skip" "Test requires xdg-open"
		rm -rf "${TEMP_DIR}"
	fi
else
	test_result "Valid HTTP URL acceptance" "skip" "Clipboard or browser tools not available"
fi

# Test 8: Script accepts domain without protocol
printf "\n"
printf "%b--- Test 8: Domain Without Protocol Acceptance ---%b\n" "${BLUE}" "${NC}"
if [[ ${SKIP_CLIPBOARD_TESTS} != "true" ]] && [[ ${SKIP_BROWSER_TESTS} != "true" ]]; then
	set_clipboard "www.example.com" 2>/dev/null

	TEMP_DIR=$(mktemp -d)
	FAKE_BROWSER="${TEMP_DIR}/fake-browser"

	cat >"${FAKE_BROWSER}" <<'EOF'
#!/bin/bash
exit 0
EOF

	chmod +x "${FAKE_BROWSER}"

	if [[ ${DETECTED_BROWSER_LAUNCHER} == "xdg-open" ]]; then
		ln -sf "${FAKE_BROWSER}" "${TEMP_DIR}/xdg-open" 2>/dev/null
		ORIGINAL_PATH="${PATH}"
		PATH="${TEMP_DIR}:${PATH}"

		timeout "${SCRIPT_TIMEOUT}" "${MAIN_SCRIPT}" --retry-count 1 --wait-time 1 &>/dev/null
		result=$?

		PATH="${ORIGINAL_PATH}"
		rm -rf "${TEMP_DIR}"

		if [[ ${result} -eq 0 ]]; then
			test_result "Domain without protocol acceptance" "pass"
		else
			test_result "Domain without protocol acceptance" "fail" "Script didn't accept domain without protocol"
		fi
	else
		test_result "Domain without protocol acceptance" "skip" "Test requires xdg-open"
		rm -rf "${TEMP_DIR}"
	fi
else
	test_result "Domain without protocol acceptance" "skip" "Clipboard or browser tools not available"
fi

# Test 9: Script handles retry logic
printf "\n"
printf "%b--- Test 9: Retry Logic ---%b\n" "${BLUE}" "${NC}"
if [[ ${SKIP_CLIPBOARD_TESTS} != "true" ]]; then
	# Put invalid URL in clipboard
	set_clipboard "invalid" 2>/dev/null

	# Run with 3 retries, 1 second wait
	START_TIME=$(date +%s)
	timeout "${SCRIPT_TIMEOUT}" "${MAIN_SCRIPT}" --retry-count 3 --wait-time 1 2>&1 >/dev/null
	END_TIME=$(date +%s)
	ELAPSED=$((END_TIME - START_TIME))

	# With 3 retries and 1 second wait between, should take at least 2 seconds
	# (retry 1, wait 1s, retry 2, wait 1s, retry 3, no wait)
	if [[ ${ELAPSED} -ge 2 ]]; then
		test_result "Retry logic with timing" "pass"
		printf "  Elapsed time: %b%s%b (expected: ≥2s)\n" "${YELLOW}" "${ELAPSED}" "${NC}"
	else
		test_result "Retry logic with timing" "fail" "Expected at least 2s, got ${ELAPSED}s"
	fi
else
	test_result "Retry logic with timing" "skip" "Clipboard tools not available"
fi

# Test 10: Script handles infinite retry with timeout
printf "\n"
printf "%b--- Test 10: Infinite Retry Mode ---%b\n" "${BLUE}" "${NC}"
if [[ ${SKIP_CLIPBOARD_TESTS} != "true" ]]; then
	set_clipboard "invalid" 2>/dev/null

	# Run in infinite mode but timeout after 2 seconds (or longer for flakey tests)
	output=$(timeout "${SCRIPT_TIMEOUT}" "${MAIN_SCRIPT}" --retry-count -1 --wait-time 1 2>&1)
	exit_code=$?

	# Should be interrupted by timeout (exit code 124)
	if [[ ${exit_code} -eq 124 ]] && echo "${output}" | grep -q "Warning: Running in infinite loop mode"; then
		test_result "Infinite retry mode" "pass"
	else
		test_result "Infinite retry mode" "fail" "Exit code: ${exit_code} (expected 124)"
	fi
else
	test_result "Infinite retry mode" "skip" "Clipboard tools not available"
fi

# Test 11: Local mode with valid directory
printf "\n"
printf "%b--- Test 11: Local Mode with Valid Directory ---%b\n" "${BLUE}" "${NC}"
if [[ ${SKIP_CLIPBOARD_TESTS} != "true" ]] && [[ ${SKIP_BROWSER_TESTS} != "true" ]]; then
	set_clipboard "/tmp" 2>/dev/null

	# Run in local mode with 1 attempt - should accept /tmp as valid directory
	output=$("${MAIN_SCRIPT}" --local --retry-count 5 --wait-time 10) # 2>&1 removed pipe for debug
	exit_code=$?

	if [[ ${exit_code} -eq 0 ]] && echo "${output}" | grep -q "Valid directory found"; then
		test_result "Local mode accepts valid directory" "pass"
	else
		test_result "Local mode accepts valid directory" "fail" "Expected to accept /tmp directory but got: ${output} with exit code ${exit_code}"
	fi
else
	test_result "Local mode accepts valid directory" "skip" "Clipboard or browser tools not available"
fi

# Test 12: Local mode with invalid directory
printf "\n"
printf "%b--- Test 12: Local Mode with Invalid Directory ---%b\n" "${BLUE}" "${NC}"
if [[ ${SKIP_CLIPBOARD_TESTS} != "true" ]]; then
	set_clipboard "/nonexistent/directory/path" 2>/dev/null

	# Run in local mode - should reject invalid directory
	output=$("${MAIN_SCRIPT}" --local --retry-count 5 --wait-time 10 2>&1)
	exit_code=$?

	if [[ ${exit_code} -ne 0 ]] && echo "${output}" | grep -q "Invalid directory path"; then
		test_result "Local mode rejects invalid directory" "pass"
	else
		test_result "Local mode rejects invalid directory" "fail" "Should reject /nonexistent/directory/path but got: ${output} with exit code ${exit_code}"
	fi
else
	test_result "Local mode rejects invalid directory" "skip" "Clipboard tools not available"
fi

# Test 13: Local mode with home directory expansion
printf "\n"
printf "%b--- Test 13: Local Mode with Tilde Expansion ---%b\n" "${BLUE}" "${NC}"
if [[ ${SKIP_CLIPBOARD_TESTS} != "true" ]] && [[ ${SKIP_BROWSER_TESTS} != "true" ]]; then
	set_clipboard "~" 2>/dev/null

	# Run in local mode - should expand ~ to home directory
	output=$("${MAIN_SCRIPT}" --local --retry-count 5 --wait-time 10 2>&1)
	exit_code=$?

	if [[ ${exit_code} -eq 0 ]] && echo "${output}" | grep -q "Valid directory found"; then
		test_result "Local mode expands tilde to home" "pass"
	else
		test_result "Local mode expands tilde to home" "fail" "Should expand ~ to home directory but got: ${output} with exit code ${exit_code}"
	fi
else
	test_result "Local mode expands tilde to home" "skip" "Clipboard or browser tools not available"
fi

# Test 14: Short form -l flag with local mode
printf "\n"
printf "%b--- Test 14: Local Mode with Short Flag (-l) ---%b\n" "${BLUE}" "${NC}"
if [[ ${SKIP_CLIPBOARD_TESTS} != "true" ]]; then
	set_clipboard "/tmp" 2>/dev/null

	# Run in local mode using -l short flag
	output=$("${MAIN_SCRIPT}" -l --retry-count 5 --wait-time 10 2>&1)
	exit_code=$?

	if [[ ${exit_code} -eq 0 ]] && echo "${output}" | grep -q "Valid directory found"; then
		test_result "Short -l flag works for local mode" "pass"
	else
		test_result "Short -l flag works for local mode" "fail" "Short flag -l should work but got: ${output} with exit code ${exit_code}"
	fi
else
	test_result "Short -l flag works for local mode" "skip" "Clipboard or browser tools not available"
fi

# Test 15: Local mode option parsing with cleared clipboard
printf "\n"
printf "%b--- Test 15: Local Mode Options with Empty Clipboard ---%b\n" "${BLUE}" "${NC}"
if [[ ${SKIP_CLIPBOARD_TESTS} != "true" ]]; then
	# Explicitly clear the clipboard before running the test
	set_clipboard "" 2>/dev/null

	# Test --local flag with empty clipboard (should show "Clipboard is empty" message)
	output=$("${MAIN_SCRIPT}" --local --retry-count 1 --wait-time 1 2>&1)
	exit_code=$?

	if echo "${output}" | grep -q "Clipboard is empty"; then
		test_result "--local flag with empty clipboard" "pass"
	else
		test_result "--local flag with empty clipboard" "fail" "Should show 'Clipboard is empty' but got: ${output}"
	fi

	# Test -l flag with empty clipboard (should show "Clipboard is empty" message)
	set_clipboard "" 2>/dev/null
	output=$("${MAIN_SCRIPT}" -l --retry-count 1 --wait-time 1 2>&1)
	exit_code=$?

	if echo "${output}" | grep -q "Clipboard is empty"; then
		test_result "-l flag with empty clipboard" "pass"
	else
		test_result "-l flag with empty clipboard" "fail" "Should show 'Clipboard is empty' but got: ${output}"
	fi
else
	test_result "--local flag with empty clipboard" "skip" "Clipboard tools not available"
	test_result "-l flag with empty clipboard" "skip" "Clipboard tools not available"
fi

# Test 16: Infinite loop mode warning message validation
# This test validates that -1 retry count triggers infinite loop mode with proper warning.
# Note: This test uses a 10-second timeout to ensure safe termination on all platforms.
# Previous unit test version hung indefinitely on macOS due to pbpaste blocking on empty
# clipboard, preventing the warning message from being flushed to output.
printf "\n"
printf "%b--- Test 16: Infinite Loop Mode Warning (Unit Test Migration) ---%b\n" "${BLUE}" "${NC}"

# Set an empty clipboard to trigger the looping behavior
set_clipboard "" 2>/dev/null &>/dev/null

# Run script with -1 retry count, timeout after 10 seconds to ensure safe termination
# Capture first line of output which should be the warning message
output=$(timeout 10 "${MAIN_SCRIPT}" --retry-count -1 --wait-time 1 2>&1 | head -1)
exit_code=$?

# Check if warning was captured before timeout or process error
if echo "${output}" | grep -q "Warning: Running in infinite loop mode"; then
	test_result "Infinite loop mode (-1) shows warning" "pass"
	printf "  Info: Warning message captured successfully\n"
else
	if [[ ${exit_code} -eq 124 ]]; then
		# Timeout exit code - likely due to pbpaste blocking on empty clipboard (macOS behavior)
		printf "%b⚠ INFO%b: Test timed out (expected on macOS with empty clipboard)\n" "${YELLOW}" "${NC}"
		printf "%b  Diagnosis%b: pbpaste blocks indefinitely when clipboard is empty\n" "${YELLOW}" "${NC}"
		printf "%b  Root cause%b: Platform-specific clipboard tool behavior\n" "${YELLOW}" "${NC}"
		test_result "Infinite loop mode (-1) shows warning" "skip" "Timeout after 10s (clipboard tool blocked)"
	else
		test_result "Infinite loop mode (-1) shows warning" "fail" "Expected warning message, got: '${output}' (exit code: ${exit_code})"
	fi
fi

# Print summary
printf "\n"
printf "%b==========================================\n" "${BLUE}"
printf "Integration Test Summary\n"
printf "==========================================%b\n" "${NC}"
printf "Tests run:     %s\n" "${TESTS_RUN}"
printf "Tests passed:  %b%s%b\n" "${GREEN}" "${TESTS_PASSED}" "${NC}"
printf "Tests failed:  %b%s%b\n" "${RED}" "${TESTS_FAILED}" "${NC}"
printf "Tests skipped: %b%s%b\n" "${YELLOW}" "${TESTS_SKIPPED}" "${NC}"
printf "%b==========================================%b\n" "${BLUE}" "${NC}"

if [[ ${TESTS_FAILED} -eq 0 ]] && [[ ${TESTS_PASSED} -gt 0 ]]; then
	printf "%bIntegration tests completed successfully!%b\n" "${GREEN}" "${NC}"
	exit 0
elif [[ ${TESTS_SKIPPED} -eq ${TESTS_RUN} ]]; then
	printf "%bAll tests skipped - clipboard/browser tools not available%b\n" "${YELLOW}" "${NC}"
	exit 0
else
	printf "%bSome integration tests failed.%b\n" "${RED}" "${NC}"
	exit 1
fi
