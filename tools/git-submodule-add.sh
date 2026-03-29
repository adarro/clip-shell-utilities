#!/usr/bin/env bash

# Git Submodule Add Helper
# Adds a git submodule to the current repository with validation
#
# Usage: git-submodule-add.sh <repository_url> [submodule_path]
#
# Arguments:
#   repository_url     - URL of the repository to add as submodule (required)
#   submodule_path     - Path where submodule will be created (optional, defaults to repo name)
#
# Examples:
#   ./git-submodule-add.sh https://github.com/example/repo.git
#   ./git-submodule-add.sh https://github.com/example/repo.git modules/example
#
# Exit Codes:
#   0 - Success: submodule added
#   1 - Submodule already exists at the specified path
#   2 - Invalid arguments or missing git
#   3 - Git operation failed
#   4 - Path already exists but is not a git submodule

set -euo pipefail

# ============= Configuration =============
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============= Helper Functions =============

print_error() {
	echo "ERROR: $*" >&2
}

print_warning() {
	echo "WARNING: $*" >&2
}

print_info() {
	echo "INFO: $*"
}

# ============= Validation =============

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
	print_error "Invalid number of arguments"
	echo "Usage: $SCRIPT_NAME <repository_url> [submodule_path]" >&2
	exit 2
fi

# Check if git is available
if ! command -v git &>/dev/null; then
	print_error "git is not installed or not in PATH"
	exit 2
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
	print_error "Not in a git repository. Please run this from the root of a git repository."
	exit 2
fi

readonly REPO_URL="$1"
readonly SUBMODULE_PATH="${2:-.}"

# Infer submodule path from repo URL if not provided and SUBMODULE_PATH is "."
if [ "$SUBMODULE_PATH" = "." ]; then
	# Extract repo name from URL (remove .git suffix if present, get last component)
	inferred_name=$(basename "$REPO_URL" | sed 's/\.git$//')
	readonly FINAL_PATH="$inferred_name"
else
	readonly FINAL_PATH="$SUBMODULE_PATH"
fi

# ============= Check if Submodule Already Exists =============

# Method 1: Check .git/config
if git config --file .gitmodules --name-only --get-regexp "submodule.*path" 2>/dev/null | grep -q "$FINAL_PATH"; then
	print_warning "Submodule already exists at path: $FINAL_PATH"
	exit 1
fi

# Method 2: Check if path exists as git submodule entry
if git config --get "submodule.$FINAL_PATH.url" &>/dev/null; then
	print_warning "Submodule '$FINAL_PATH' is already registered in git config"
	exit 1
fi

# Method 3: Check if path exists and is not empty (potential conflict)
if [ -d "$FINAL_PATH" ] && [ -n "$(find "$FINAL_PATH" -mindepth 1 2>/dev/null)" ]; then
	# Check if it's already a submodule
	if [ -f "$FINAL_PATH/.git" ] || [ -d "$FINAL_PATH/.git" ]; then
		print_warning "Path exists and appears to be a submodule: $FINAL_PATH"
		exit 1
	fi
	print_warning "Path exists and is not empty: $FINAL_PATH"
	exit 4
fi

# ============= Add Submodule =============

print_info "Adding submodule from $REPO_URL to $FINAL_PATH..."

if git submodule add "$REPO_URL" "$FINAL_PATH"; then
	print_info "✓ Submodule added successfully at: $FINAL_PATH"
	exit 0
else
	print_error "Failed to add submodule"
	exit 3
fi
