#!/usr/bin/env bash

# Check clipboard for valid URL and open in browser
# Usage: ./check-clipboard-url.sh [OPTIONS]
# Options:
#   --retry-count N       Number of retries (-1 for infinite)
#   --wait-time N         Wait time in seconds between retries (minimum: 1)
#   --local, -l           Treat clipboard content as local file path instead of URL
#
# Examples:
#   ./check-clipboard-url.sh                    # defaults: 5 retries, 2s wait
#   ./check-clipboard-url.sh --retry-count 10
#   ./check-clipboard-url.sh --wait-time 1 --local
#   ./check-clipboard-url.sh -l                 # short form for --local

# Default configuration
RETRY_COUNT=5
WAIT_TIME=2
LOCAL_MODE=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
	case $1 in
	--retry-count)
		RETRY_COUNT="$2"
		shift 2
		;;
	--wait-time)
		WAIT_TIME="$2"
		shift 2
		;;
	--local | -l)
		LOCAL_MODE=true
		shift
		;;
	*)
		echo "Unknown option: $1"
		echo "Usage: $0 [--retry-count N] [--wait-time N] [--local|-l]"
		exit 1
		;;
	esac
done

# Validate that retry count and wait time are valid
# retry count: positive integer or -1 for infinite
if ! [[ ${RETRY_COUNT} =~ ^-?[0-9]+$ ]] || ([[ ${RETRY_COUNT} -lt 1 ]] && [[ ${RETRY_COUNT} -ne -1 ]]); then
	echo "Error: --retry-count must be a positive integer or -1 for infinite retries"
	exit 1
fi

# wait time must be at least 1 second
if ! [[ ${WAIT_TIME} =~ ^[0-9]+$ ]] || [[ ${WAIT_TIME} -lt 1 ]]; then
	echo "Error: --wait-time must be at least 1 second (minimum: 1)"
	exit 1
fi

# Warn if infinite looping is enabled
if [[ ${RETRY_COUNT} -eq -1 ]]; then
	echo "Warning: Running in infinite loop mode (--retry-count -1). Press Ctrl+C to exit."
fi

# Function to validate URL
is_valid_url() {
	local url="$1"

	# Check if URL starts with http:// or https://
	if [[ ${url} =~ ^https?:// ]]; then
		return 0
	fi

	# Check if it looks like a valid domain without protocol
	# Must contain at least one dot (for TLD)
	if [[ ${url} =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$ ]]; then
		return 0
	fi

	return 1
}

# Function to validate local directory path
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

# Function to detect if running in WSL
is_wsl() {
	[[ -f /proc/version ]] && grep -q -i "microsoft\|wsl" /proc/version
	return $?
}

# Function to get clipboard content (uses pre-detected CLIPBOARD_TOOL)
get_clipboard() {
	case "${CLIPBOARD_TOOL}" in
	xclip)
		xclip -selection clipboard -o 2>/dev/null
		;;
	xsel)
		xsel --clipboard --output 2>/dev/null
		;;
	pbpaste)
		pbpaste 2>/dev/null
		;;
	powershell.exe)
		powershell.exe -command "Get-Clipboard" 2>/dev/null | tr -d '\r'
		;;
	*)
		return 1
		;;
	esac
}

# Function to open URL in browser (uses pre-detected BROWSER_LAUNCHER)
open_browser() {
	local url="$1"
	# replace tilde with $HOME variable for proper expansion
	if [[ ${url} =~ ^~ ]]; then
		url="${url/#~/${HOME}}"
	fi

	# Add protocol if not present (and not a file path)
	if [[ ! ${url} =~ ^https?:// ]] && [[ ! ${url} =~ ^file:// ]] && [[ ! ${url} =~ ^/ ]]; then
		url="https://${url}"
	fi
	printf "launching browser to %s using %s" "${url}" "${BROWSER_LAUNCHER}"
	case "${BROWSER_LAUNCHER}" in
	xdg-open)
		xdg-open "${url}" &>/dev/null &
		;;
	open)
		open "${url}" &>/dev/null &
		;;
	*)
		echo "Error: No valid browser launcher available"
		return 1
		;;
	esac
}

# ============= Tool Detection (run once at initialization) =============
# Detect available clipboard tool
detect_clipboard_tool() {
	if command -v xclip &>/dev/null; then
		echo "xclip"
	elif command -v xsel &>/dev/null; then
		echo "xsel"
	elif command -v pbpaste &>/dev/null; then
		echo "pbpaste"
	elif is_wsl && command -v powershell.exe &>/dev/null; then
		echo "powershell.exe"
	else
		return 1
	fi
}

# Detect available browser launcher
detect_browser_launcher() {
	if command -v xdg-open &>/dev/null; then
		echo "xdg-open"
	elif command -v open &>/dev/null; then
		echo "open"
	else
		return 1
	fi
}

# Initialize tool detection at startup (runs AFTER all functions are defined)
CLIPBOARD_TOOL=$(detect_clipboard_tool) || {
	echo "Error: No clipboard tool available (xclip, xsel, pbpaste, or PowerShell)"
	exit 1
}
BROWSER_LAUNCHER=$(detect_browser_launcher) || {
	echo "Error: No browser launcher found (xdg-open or open)"
	exit 1
}

# Main loop
attempt=0
while true; do
	# Check if we've exceeded retry count (skip if RETRY_COUNT is -1 for infinite)
	if [[ ${RETRY_COUNT} -ne -1 ]] && [[ ${attempt} -ge ${RETRY_COUNT} ]]; then
		break
	fi
	attempt=$((attempt + 1))

	clipboard=$(get_clipboard) || {
		echo "Error: Could not access clipboard"
		exit 1
	}

	if [[ -z ${clipboard} ]]; then
		echo "Attempt ${attempt}/${RETRY_COUNT}: Clipboard is empty. Waiting ${WAIT_TIME}s..."
		sleep "${WAIT_TIME}"
		continue
	fi

	if [[ ${LOCAL_MODE} == true ]]; then
		# Validate as local directory path
		if is_valid_directory "${clipboard}"; then
			echo "Valid directory found: ${clipboard}"
			if open_browser "${clipboard}"; then
				echo "Opening directory in file manager..."
				exit 0
			else
				echo "Failed to open file manager"
				exit 1
			fi
		else
			echo "Attempt ${attempt}/${RETRY_COUNT}: Invalid directory path: ${clipboard}"
			if [[ ${RETRY_COUNT} -eq -1 ]] || [[ ${attempt} -lt ${RETRY_COUNT} ]]; then
				echo "Waiting ${WAIT_TIME}s before retry..."
				sleep "${WAIT_TIME}"
			fi
		fi
	else
		# Validate as URL
		if is_valid_url "${clipboard}"; then
			echo "Valid URL found: ${clipboard}"
			if open_browser "${clipboard}"; then
				echo "Opening URL in default browser..."
				exit 0
			else
				echo "Failed to open browser"
				exit 1
			fi
		else
			# Display attempt count differently for infinite loop
			if [[ ${RETRY_COUNT} -eq -1 ]]; then
				echo "Attempt ${attempt}: Invalid URL in clipboard: ${clipboard}"
			else
				echo "Attempt ${attempt}/${RETRY_COUNT}: Invalid URL in clipboard: ${clipboard}"
			fi

			# Check if we should retry
			if [[ ${RETRY_COUNT} -eq -1 ]] || [[ ${attempt} -lt ${RETRY_COUNT} ]]; then
				echo "Waiting ${WAIT_TIME}s before retry..."
				sleep "${WAIT_TIME}"
			fi
		fi
	fi
done

if [[ ${RETRY_COUNT} -eq -1 ]]; then
	if [[ ${LOCAL_MODE} == true ]]; then
		echo "Interrupted: Failed to find valid directory path during infinite loop."
	else
		echo "Interrupted: Failed to find valid URL in clipboard during infinite loop."
	fi
else
	if [[ ${LOCAL_MODE} == true ]]; then
		echo "Failed to find valid directory path after ${RETRY_COUNT} attempts."
	else
		echo "Failed to find valid URL in clipboard after ${RETRY_COUNT} attempts."
	fi
fi
exit 1
