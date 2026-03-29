# Justfile for check-clipboard-url project
# Install: https://github.com/casey/just
# Usage: just <recipe>
#
# MODULE USAGE (via environment variables):
# ==========================================
# Parent justfile can pass parameters by setting environment variables:
#   CLIPBOARD_RETRY_COUNT=10 just clipp::url
#   CLIPBOARD_WAIT_TIME=3 just clipp::url
#   CLIPBOARD_MODE=local just clipp::url
#
# STANDALONE USAGE:
# =================
# Direct execution: just url, just local, just check, etc.

import? 'gittools.just'

set shell := ["bash", "-c"]
set positional-arguments := true
set quiet := true

# ============= Configuration via Environment Variables =============
# Read environment variables if set, otherwise use defaults via bash
# This allows parent justfiles to override them easily

export CLIPBOARD_RETRY_COUNT := `if [ -n "${CLIPBOARD_RETRY_COUNT:-}" ]; then echo "${CLIPBOARD_RETRY_COUNT}"; else echo "5"; fi`
export CLIPBOARD_WAIT_TIME := `if [ -n "${CLIPBOARD_WAIT_TIME:-}" ]; then echo "${CLIPBOARD_WAIT_TIME}"; else echo "2"; fi`
export CLIPBOARD_MODE := `if [ -n "${CLIPBOARD_MODE:-}" ]; then echo "${CLIPBOARD_MODE}"; else echo "url"; fi`

# ============= Default actions =============

# Set the default recipe to 'usage' which shows quick reference
@default: usage

# ============= Core Flexible Recipe =============
# Main recipe that uses exported environment variables
# Usage: just check

# Or from parent: CLIPBOARD_RETRY_COUNT=10 just clipp::check
@check:
    #!/usr/bin/env bash
    set -euo pipefail

    # Environment variables are already exported and accessible
    retry_count="${CLIPBOARD_RETRY_COUNT}"
    wait_time="${CLIPBOARD_WAIT_TIME}"
    check_mode="${CLIPBOARD_MODE}"

    # Build command arguments
    declare -a args=()
    [[ "$check_mode" == "local" ]] && args+=(--local)
    [[ "$retry_count" != "5" ]] && args+=(--retry-count "$retry_count")
    [[ "$wait_time" != "2" ]] && args+=(--wait-time "$wait_time")

    ./check-clipboard-url.sh "${args[@]}"

# ============= Convenience Recipes (Standalone & Module-friendly) =============
# These recipes work both standalone and as module recipes
# They respect environment variables set by parent justfiles

# Display all available recipes
@help:
    just --list

# Run the clipboard URL checker with configured settings (respects CLIPBOARD_* env vars)
@url:
    #!/usr/bin/env bash
    set -euo pipefail

    declare -a args=()
    [[ "${CLIPBOARD_MODE}" == "local" ]] && args+=(--local)
    [[ "${CLIPBOARD_RETRY_COUNT}" != "5" ]] && args+=(--retry-count "${CLIPBOARD_RETRY_COUNT}")
    [[ "${CLIPBOARD_WAIT_TIME}" != "2" ]] && args+=(--wait-time "${CLIPBOARD_WAIT_TIME}")

    ./check-clipboard-url.sh "${args[@]}"

# Run the clipboard URL checker in local mode (directory path)
# Usage: just local

# Or override retries/wait from parent: CLIPBOARD_RETRY_COUNT=10 just clipp::local
@local:
    #!/usr/bin/env bash
    set -euo pipefail

    declare -a args=(--local)
    [[ "${CLIPBOARD_RETRY_COUNT}" != "5" ]] && args+=(--retry-count "${CLIPBOARD_RETRY_COUNT}")
    [[ "${CLIPBOARD_WAIT_TIME}" != "2" ]] && args+=(--wait-time "${CLIPBOARD_WAIT_TIME}")

    ./check-clipboard-url.sh "${args[@]}"

# Run with custom retry count
# Usage: just url-retry 10  (standalone)

# Or override from parent: CLIPBOARD_RETRY_COUNT=10 just clipp::url
@url-retry count:
    #!/usr/bin/env bash
    set -euo pipefail

    declare -a args=()
    [[ "${CLIPBOARD_MODE}" == "local" ]] && args+=(--local)
    args+=(--retry-count {{ count }})
    [[ "${CLIPBOARD_WAIT_TIME}" != "2" ]] && args+=(--wait-time "${CLIPBOARD_WAIT_TIME}")

    ./check-clipboard-url.sh "${args[@]}"

# Run with custom wait time (seconds)

# Usage: just url-wait 5  (standalone)
@url-wait seconds:
    #!/usr/bin/env bash
    set -euo pipefail

    declare -a args=()
    [[ "${CLIPBOARD_MODE}" == "local" ]] && args+=(--local)
    [[ "${CLIPBOARD_RETRY_COUNT}" != "5" ]] && args+=(--retry-count "${CLIPBOARD_RETRY_COUNT}")
    args+=(--wait-time {{ seconds }})

    ./check-clipboard-url.sh "${args[@]}"

# Run in infinite loop mode
@url-infinite:
    #!/usr/bin/env bash
    set -euo pipefail

    declare -a args=()
    [[ "${CLIPBOARD_MODE}" == "local" ]] && args+=(--local)
    args+=(--retry-count -1)
    [[ "${CLIPBOARD_WAIT_TIME}" != "2" ]] && args+=(--wait-time "${CLIPBOARD_WAIT_TIME}")

    ./check-clipboard-url.sh "${args[@]}"

# Run in infinite loop mode with custom wait time
@url-infinite-wait seconds:
    #!/usr/bin/env bash
    set -euo pipefail

    declare -a args=()
    [[ "${CLIPBOARD_MODE}" == "local" ]] && args+=(--local)
    args+=(--retry-count -1 --wait-time {{ seconds }})

    ./check-clipboard-url.sh "${args[@]}"

# Run in local mode with infinite retries
@local-infinite:
    #!/usr/bin/env bash
    set -euo pipefail

    declare -a args=(--local --retry-count -1)
    [[ "${CLIPBOARD_WAIT_TIME}" != "2" ]] && args+=(--wait-time "${CLIPBOARD_WAIT_TIME}")

    ./check-clipboard-url.sh "${args[@]}"

# Run all unit tests
@test:
    ./test-check-clipboard-url.sh

# Run integration tests
@test-integration flakey-tests="false":
    if [ "{{ flakey-tests }}" = "true" ]; then
    echo "Running integration tests including flakey tests..."
    ./integration-test-check-clipboard-url.sh --flakey-tests
    else
    echo "Running integration tests (excluding flakey tests)..."
    ./integration-test-check-clipboard-url.sh
    fi

# Run unit tests with verbose output
@test-verbose:
    bash -x ./test-check-clipboard-url.sh

# Run only quick tests (skip slow operations)
@test-quick:
    ./test-check-clipboard-url.sh 2>&1 | head -50

# Run all tests (unit + integration)
@test-all:
    echo "=== Running Unit Tests ==="
    ./test-check-clipboard-url.sh
    echo ""
    echo "=== Running Integration Tests ==="
    ./integration-test-check-clipboard-url.sh  --flakey-tests

# Make all scripts executable
@setup:
    chmod +x check-clipboard-url.sh
    chmod +x test-check-clipboard-url.sh
    chmod +x integration-test-check-clipboard-url.sh
    echo "✓ All scripts are now executable"

# Display version/help for the main script
@info:
    head -20 ./check-clipboard-url.sh | grep -A 10 "^# Check clipboard"

# Generate a quick demo (puts example URL in clipboard and runs)
@demo:
    #!/bin/bash
    echo "Demo: Setting clipboard to https://github.com and opening..."
    if command -v xclip &>/dev/null; then
        echo "https://github.com" | xclip -selection clipboard
        echo "Running: ./check-clipboard-url.sh"
        timeout 3 ./check-clipboard-url.sh || true
    elif command -v powershell.exe &>/dev/null; then
        echo "Running demo in WSL..."
        powershell.exe -command "'https://github.com' | Set-Clipboard"
        timeout 3 ./check-clipboard-url.sh || true
    else
        echo "Error: No clipboard tool available"
        exit 1
    fi

# Create a temporary test directory and run local mode demo
@demo-local:
    #!/bin/bash
    TEMP_DIR=$(mktemp -d)
    echo "Created test directory: $TEMP_DIR"
    touch "$TEMP_DIR/test-file.txt"
    echo "test content" > "$TEMP_DIR/test-file.txt"
    echo ""
    echo "Demo: Setting clipboard to $TEMP_DIR and opening..."
    if command -v xclip &>/dev/null; then
        echo "$TEMP_DIR" | xclip -selection clipboard
        timeout 3 ./check-clipboard-url.sh --local || true
    elif command -v powershell.exe &>/dev/null; then
        powershell.exe -command "'$TEMP_DIR' | Set-Clipboard"
        timeout 3 ./check-clipboard-url.sh --local || true
    else
        echo "Error: No clipboard tool available"
        exit 1
    fi
    echo ""
    echo "Cleaning up: $TEMP_DIR"
    rm -rf "$TEMP_DIR"

# Watch for changes and run tests
@watch:
    #!/bin/bash
    if ! command -v watch &>/dev/null; then
        echo "Error: 'watch' command not found. Install it to use this recipe."
        exit 1
    fi
    watch -n 2 'clear && echo "Last run: $(date)" && echo "" && ./test-check-clipboard-url.sh 2>&1 | tail -20'

# Lint the main script with ShellCheck (if available)
@lint:
    #!/bin/bash
    if command -v shellcheck &>/dev/null; then
        echo "Linting scripts with ShellCheck..."
        shellcheck check-clipboard-url.sh || true
        shellcheck test-check-clipboard-url.sh || true
        shellcheck integration-test-check-clipboard-url.sh || true
    else
        echo "ShellCheck not found. Install it to lint scripts."
        echo "  Ubuntu/Debian: sudo apt-get install shellcheck"
        echo "  macOS: brew install shellcheck"
        exit 1
    fi

# Display quick usage reference
@usage:
    echo "check-clipboard-url.sh - Clipboard URL Opener"
    echo ""
    echo "Quick Reference:"
    echo "  just url              - Check clipboard for URL"
    echo "  just local            - Check clipboard for directory path"
    echo "  just url-retry 10     - Set retry count to 10"
    echo "  just url-wait 5       - Set wait time to 5 seconds"
    echo "  just url-infinite     - Infinite loop mode"
    echo ""
    echo "Testing:"
    echo "  just test             - Run unit tests"
    echo "  just test-integration - Run integration tests"
    echo "  just test-all         - Run all tests"
    echo ""
    echo "Demo:"
    echo "  just demo             - Demo with example URL"
    echo "  just demo-local       - Demo with local directory"
    echo ""
    echo "Serve:"
    echo "  just serve            - Serve with npx serve (uses HTTP_SERVE env var)"
    echo "  just serve <path>     - Serve specific directory"

# Serve directory with npx serve in a new terminal window
@serve path='':
    #!/bin/bash
    if [ -z "{{ path }}" ]; then
        URL="${HTTP_SERVE:-.}"
    else
        URL="{{ path }}"
    fi

    # Try different terminal emulators in order of preference
    if command -v gnome-terminal &>/dev/null; then
        gnome-terminal -- npx serve "$URL" &
    elif command -v xfce4-terminal &>/dev/null; then
        xfce4-terminal -e "npx serve \"$URL\"" &
    elif command -v konsole &>/dev/null; then
        konsole -e npx serve "$URL" &
    elif command -v xterm &>/dev/null; then
        xterm -e npx serve "$URL" &
    elif command -v x-terminal-emulator &>/dev/null; then
        x-terminal-emulator -e npx serve "$URL" &
    else
        echo "Error: No terminal emulator found. Please install one of:"
        echo "  - gnome-terminal"
        echo "  - xfce4-terminal"
        echo "  - konsole"
        echo "  - xterm"
        exit 1
    fi
    echo "✓ Started npx serve for: $URL"
    echo "Opening browser when ready..."
    ./check-clipboard-url.sh || true
