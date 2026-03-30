# Git tools for Justfile
# Functions for managing git submodules with convenient just recipes

# enable parent tracking
set fallback

# ============= Git Tool Helper Variables =============
# Export tools directory path for use in recipes
export GITTOOLS_DIR := source_directory() / "tools"


# The location of the initial just invocation (the directory where the just command was run)
export INVOCATION_DIR := source_directory()
# the location of this justfile
export EXECUTING_DIR := justfile_directory()
# EXECUTING_DIR == INVOCATION_DIR when the justfile is executed from its own directory (e.g. `just` run from the same directory as the justfile)

CONFIG_DIR := `git rev-parse --git-dir`

# Displays basic information about the git tools environment (for debugging and verification)
# The results may change based on the context of the just invocation (e.g. from parent justfile vs standalone)
[group('gittools')]
@git-context:
    echo "Git Tools for Justfile"
    echo "Environment:"
    printf "\tTool Directory:\t\t %s\n" "${GITTOOLS_DIR}"
    printf "\tSource Directory:\t %s\n" "${INVOCATION_DIR}"
    printf "\tJustFile Directory:\t %s\n" "${EXECUTING_DIR}"
    printf "\tGit Config Directory:\t %s\n" "{{CONFIG_DIR}}"
    echo ""

# ============= Git Submodule Operations =============

# Add a git submodule to the current repository
# 
# Validates that the submodule doesn't already exist and adds it cleanly.
# On success (exit 0): submodule is created
# On collision (exit 1): submodule path already exists (fails gracefully with warning)
# On error (exit 2+): validation or git operation failed
#
# Usage (standalone):
#   just addSubmodule -- https://github.com/example/repo.git
#   just addSubmodule -- https://github.com/example/repo.git modules/example
#
# Usage (from parent justfile):
#   just git::addSubmodule -- https://github.com/example/repo.git modules/example
[group('gittools')]
@addSubmodule url path="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    if [ -z "{{url}}" ]; then
        echo "ERROR: Repository URL is required" >&2
        echo "Usage: just addSubmodule -- <repository_url> [submodule_path]" >&2
        exit 2
    fi
    
    script_path="${GITTOOLS_DIR}/git-submodule-add.sh"
    
    if [ -n "{{path}}" ]; then
        "$script_path" "{{url}}" "{{path}}"
    else
        "$script_path" "{{url}}"
    fi

# Remove a git submodule from the current repository (basic mode)
#
# Removes the submodule directory, configuration, and cache. 
# Warns if uncommitted changes are present but proceeds anyway.
#
# On success (exit 0): submodule is removed and committed
# On error (exit 1+): submodule not found or operation failed
#
# Usage (standalone):
#   just removeSubmodule -- modules/example
#
# Usage (from parent justfile):
#   just git::removeSubmodule -- modules/example
[group('gittools')]
@removeSubmodule path="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    if [ -z "{{path}}" ]; then
        echo "ERROR: Submodule path is required" >&2
        echo "Usage: just removeSubmodule -- <submodule_path>" >&2
        exit 2
    fi
    
    script_path="${GITTOOLS_DIR}/git-submodule-remove.py"
    "$script_path" "{{path}}"

# Remove a git submodule safely with automatic checkpoint/restore
#
# Creates a pre-commit snapshot (stashes uncommitted changes) before removal.
# If removal succeeds: snapshot is discarded and changes are unstashed
# If removal fails: snapshot is restored automatically (checkpoint/rollback)
#
# This is the recommended method when you have uncommitted work you want to keep safe.
#
# Usage (standalone):
#   just removeSubmodule-safe -- modules/example
#
# Usage (from parent justfile):
#   just git::removeSubmodule-safe -- modules/example
[group('gittools')]
@removeSubmodule-safe path="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    if [ -z "{{path}}" ]; then
        echo "ERROR: Submodule path is required" >&2
        echo "Usage: just removeSubmodule-safe -- <submodule_path>" >&2
        exit 2
    fi
    
    script_path="${GITTOOLS_DIR}/git-submodule-remove.py"
    "$script_path" "{{path}}" --checkpoint

# Checks to see if a submodule already exists at the given path
#
# Usage (standalone):
#   just submodule-exists -- modules/example
#   echo "Submodule exists: $?"  # Returns 0 if exists, 1 if not
#
# Usage (from parent justfile):
#   just git::submodule-exists -- modules/example
[group('gittools')]
@submodule-exists path="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    if [ -z "{{path}}" ]; then
        echo "ERROR: Submodule path is required" >&2
        echo "Usage: just submodule-exists -- <submodule_path>" >&2
        exit 2
    fi
    
    if git config --file .gitmodules --get-regexp "submodule.*path" 2>/dev/null | grep -q "{{path}}"; then
        echo "Submodule exists at: {{path}}"
        exit 0
    else
        echo "Submodule not found at: {{path}}"
        exit 1
    fi

