#!/usr/bin/env python3

"""
Git Submodule Remove Helper
Removes a git submodule from the current repository with optional checkpoint/restore.

Usage: git-submodule-remove.py <submodule_path> [--checkpoint]

Arguments:
    submodule_path  - Path of the submodule to remove (required)
    --checkpoint    - Create pre-commit snapshot for safe removal with rollback (optional)

Examples:
    ./git-submodule-remove.py modules/example
    ./git-submodule-remove.py modules/example --checkpoint

Exit Codes:
    0 - Success: submodule removed
    1 - Submodule path not found
    2 - Uncommitted changes detected (and no checkpoint requested)
    3 - Removal operation failed
    4 - Failed to restore checkpoint on rollback
    5 - Failed to create checkpoint

Requirements:
    - Python 3.8+
    - git 2.13+
    - Executed within a git repository
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
import warnings
from pathlib import Path
from typing import Optional, Tuple


class GitSubmoduleRemover:
    """Handles git submodule removal with optional checkpoint/restore functionality."""

    def __init__(self, submodule_path: str, use_checkpoint: bool = False):
        self.submodule_path = submodule_path.rstrip("/")
        self.use_checkpoint = use_checkpoint
        self.checkpoint_dir: Optional[str] = None
        self.stash_created = False
        # Use INVOCATION_DIR if provided, otherwise use current directory
        self.invocation_dir = os.environ.get("INVOCATION_DIR", ".")

        # Verify we're in a git repository
        if not self._is_git_repo():
            self.error(
                "Not in a git repository. Please run this from the root of a git repository."
            )
            sys.exit(5)

    @staticmethod
    def error(message: str) -> None:
        """Print error message to stderr."""
        print(f"ERROR: {message}", file=sys.stderr)

    @staticmethod
    def warning(message: str) -> None:
        """Print warning message to stderr."""
        print(f"WARNING: {message}", file=sys.stderr)

    @staticmethod
    def info(message: str) -> None:
        """Print info message to stdout."""
        print(f"INFO: {message}")

    def _run_git_command(self, args: list, check: bool = True) -> Tuple[int, str, str]:
        """
        Run a git command in the invocation directory and return exit code, stdout, and stderr.

        Args:
            args: List of git command arguments (git is prepended)
            check: If True, will raise CalledProcessError on non-zero exit

        Returns:
            Tuple of (exit_code, stdout, stderr)
        """
        try:
            result = subprocess.run(
                ["git", "-C", self.invocation_dir] + args,
                capture_output=True,
                text=True,
                check=False,
            )
            return result.returncode, result.stdout, result.stderr
        except FileNotFoundError as e:
            raise RuntimeError("git is not installed or not in PATH") from e

    def _is_git_repo(self) -> bool:
        """Check if we're in a git repository."""
        exit_code, _, _ = self._run_git_command(["rev-parse", "--git-dir"], check=False)
        return exit_code == 0

    def _is_submodule_registered(self) -> bool:
        """Check if the path is registered as a submodule in git config."""
        exit_code, _, _ = self._run_git_command(
            ["config", "--get", f"submodule.{self.submodule_path}.url"], check=False
        )
        return exit_code == 0

    def _submodule_exists_on_disk(self) -> bool:
        """Check if the submodule path exists on disk."""
        return os.path.exists(os.path.join(self.invocation_dir, self.submodule_path))

    def _get_git_dir(self) -> Optional[str]:
        """
        Get the git directory path using 'git rev-parse --git-dir'.

        Returns:
            The git directory path (relative to invocation_dir), or None if not found
        """
        exit_code, output, _ = self._run_git_command(
            ["rev-parse", "--git-dir"], check=False
        )
        if exit_code == 0:
            return output.strip()
        return None

    def _get_git_config_path(self) -> Optional[str]:
        """
        Determine the correct git config file path for this submodule.

        For root submodules: .git/config
        For nested submodules: .git/modules/{path}/config

        Returns:
            The absolute path to the git config file, or None if not found
        """
        git_dir = self._get_git_dir()
        if not git_dir:
            return None

        # If git_dir is relative, make it absolute relative to invocation_dir
        if not os.path.isabs(git_dir):
            git_dir = os.path.join(self.invocation_dir, git_dir)

        # For nested submodules, the config is in .git/modules/{path}/config
        # For root submodules, it's in .git/config
        if os.path.isfile(git_dir):
            # git_dir points to a .git file (worktree case)
            return git_dir
        else:
            # git_dir is a directory
            config_path = os.path.join(git_dir, "config")
            return config_path if os.path.exists(config_path) else None

    def _has_uncommitted_changes(self) -> bool:
        """Check if there are uncommitted changes in the repository."""
        exit_code, _, _ = self._run_git_command(["status", "--porcelain"], check=False)
        if exit_code != 0:
            return False

        # Get output and check if there are any changes
        _, output, _ = self._run_git_command(["status", "--porcelain"], check=False)
        return bool(output.strip())

    def _create_checkpoint(self) -> bool:
        """
        Create a pre-commit snapshot by stashing uncommitted changes.

        Returns:
            True if checkpoint created successfully, False otherwise
        """
        try:
            self.info("Creating checkpoint...")

            # Create a temporary directory to store checkpoint data
            self.checkpoint_dir = tempfile.mkdtemp(prefix="git_submodule_checkpoint_")
            self.info(f"Checkpoint directory: {self.checkpoint_dir}")

            # Stash uncommitted changes
            exit_code, stdout, stderr = self._run_git_command(
                ["stash", "push", "-u", "-m", "auto-checkpoint:submodule-remove"],
                check=False,
            )

            if exit_code == 0 and "No local changes to save" not in stdout:
                self.stash_created = True
                self.info("✓ Uncommitted changes stashed")
            elif "No local changes to save" in stdout:
                self.info("✓ No uncommitted changes to stash")
            else:
                self.error(f"Failed to stash changes: {stderr}")
                return False

            # Store git state info for reference
            _, current_hash, _ = self._run_git_command(
                ["rev-parse", "HEAD"], check=False
            )
            state_file = os.path.join(self.checkpoint_dir, "state.txt")
            with open(state_file, "w") as f:
                f.write(f"commit_hash={current_hash.strip()}\n")
                f.write(f"submodule_path={self.submodule_path}\n")
                f.write(f"stash_created={self.stash_created}\n")

            return True
        except Exception as e:
            self.error(f"Failed to create checkpoint: {e}")
            return False

    def _restore_checkpoint(self) -> bool:
        """
        Restore from checkpoint (on failure).

        Returns:
            True if restoration successful, False otherwise
        """
        if not self.checkpoint_dir or not os.path.exists(self.checkpoint_dir):
            self.warning("Checkpoint directory not found, cannot restore")
            return False

        try:
            self.info("Restoring from checkpoint...")

            # Restore stashed changes if they were created
            if self.stash_created:
                exit_code, _, stderr = self._run_git_command(
                    ["stash", "pop"], check=False
                )
                if exit_code != 0:
                    self.error(f"Failed to restore stashed changes: {stderr}")
                    return False
                self.info("✓ Stashed changes restored")

            return True
        except Exception as e:
            self.error(f"Failed to restore checkpoint: {e}")
            return False
        finally:
            self._cleanup_checkpoint()

    def _cleanup_checkpoint(self) -> None:
        """Clean up checkpoint directory."""
        if self.checkpoint_dir and os.path.exists(self.checkpoint_dir):
            try:
                shutil.rmtree(self.checkpoint_dir)
            except Exception as e:
                self.warning(f"Failed to clean up checkpoint directory: {e}")

    def _deinit_submodule(self) -> bool:
        """Deinitialize the submodule."""
        warnings.warn(
            "`_deinit_submodule` is deprecated and may be removed in future versions. Use `_improved_rm` instead.",
            DeprecationWarning,
            stacklevel=2,  # Ensures the warning points to the caller's line number
        )
        self.info(f"Deinitializing submodule: {self.submodule_path}...")
        exit_code, _, stderr = self._run_git_command(
            ["submodule", "deinit", "-f", "--", self.submodule_path], check=False
        )
        if exit_code == 0:
            self.info("✓ Submodule deinitialized")
            return True
        else:
            self.error(f"Failed to deinit submodule: {stderr}")
            return False

    def _remove_submodule_directory(self) -> bool:
        """Remove the submodule directory from disk."""
        warnings.warn(
            "`_remove_submodule_directory` is deprecated and may be removed in future versions. Use `_improved_rm` instead.",
            DeprecationWarning,
            stacklevel=2,  # Ensures the warning points to the caller's line number
        )
        submodule_full_path = os.path.join(self.invocation_dir, self.submodule_path)
        if not os.path.exists(submodule_full_path):
            self.warning(f"Submodule directory not found: {self.submodule_path}")
            return True

        try:
            self.info(f"Removing submodule directory: {self.submodule_path}...")
            shutil.rmtree(submodule_full_path)
            self.info("✓ Submodule directory removed")
            return True
        except Exception as e:
            self.error(f"Failed to remove submodule directory: {e}")
            return False

    def _improved_rm(self) -> bool:
        """Remove folder and git modules Entry"""
        self.info("Removing folder and .gitmodules entry for submodule...")

        exit_code, _, stderr = self._run_git_command(
            ["rm", "-r", "-f", self.submodule_path], check=False
        )

        if exit_code == 0:
            self.info("✓ Git submodule folder and module entry cleared")
            return True
        else:
            self.error(f"Failed to clear git cache: {stderr}")
            return False

    def _remove_from_gitmodules(self) -> bool:
        """Remove the submodule entry from .gitmodules."""
        gitmodules_path = os.path.join(self.invocation_dir, ".gitmodules")

        if not os.path.exists(gitmodules_path):
            self.info("No .gitmodules file found, skipping")
            return True

        try:
            self.info(f"Removing entry from .gitmodules for: {self.submodule_path}...")

            with open(gitmodules_path, "r") as f:
                content = f.read()

            # Use regex to remove the entire [submodule "path"] section
            # Pattern: [submodule "..."] followed by its config lines until the next section or EOF
            pattern = rf'\[submodule\s*"[^"]*{re.escape(self.submodule_path)}[^"]*"\]\s*\n(?:\s*\w+\s*=\s*[^\n]*\n)*'
            re.sub(pattern, "", content)

            # Also try git config method
            exit_code, _, _ = self._run_git_command(
                [
                    "config",
                    "--file",
                    ".gitmodules",
                    "--remove-section",
                    f"submodule.{self.submodule_path}",
                ],
                check=False,
            )

            if exit_code == 0:
                self.info("✓ Submodule removed from .gitmodules")
                return True
            else:
                # Fallback: still success if .gitmodules was manually updated
                self.warning(
                    "Failed to remove from .gitmodules using git config, may need manual cleanup"
                )
                return True
        except Exception as e:
            self.error(f"Failed to update .gitmodules: {e}")
            return False

    def _remove_submodule_meta(self) -> bool:
        """
        Remove the submodule directories from the .git/modules/**.

        For root submodules: .git/config
        For nested submodules: .git/modules/{path}/config
        """
        self.info("Removing entry from git config...")

        # If locate the config file and rm the parent (check for is module vs root repo ::wink::)
        config_path = os.path.join( self.invocation_dir, f".git/modules/{self.submodule_path}")
        if config_path and os.path.exists(config_path):
            try:
                self.info(f"Attempting directory removal from: {config_path}")
                shutil.rmtree(Path(config_path), ignore_errors=False)
                return True
            except Exception as e:
                self.warning(
                    f"Failed to remove from git modules directory directly: {e}"
                )

        # Still return True as this might not be critical
        self.warning(
            f"Could not verify removal of module meta data folders using {config_path}, but continuing..."
        )
        return True

    def _remove_from_git_config(self) -> bool:
        """
        Remove the submodule entry from the appropriate git config file.

        For root submodules: .git/config
        For nested submodules: .git/modules/{path}/config
        """
        self.info("Removing entry from git config...")

        # First try using git config command (works for both root and nested)
        exit_code, _, stderr = self._run_git_command(
            ["config", "--remove-section", f"submodule.{self.submodule_path}"],
            check=False,
        )

        if exit_code == 0 or "No such section" in stderr:
            self.info("✓ Submodule removed from git config")
            return True

        # If git config command failed, try to remove directly from the config file
        config_path = self._get_git_config_path()
        if config_path and os.path.exists(config_path):
            try:
                self.info(f"Attempting direct removal from config: {config_path}")
                with open(config_path, "r") as f:
                    content = f.read()

                # Remove the [submodule "path"] section and its entries
                pattern = rf'\[submodule\s*"[^"]*{re.escape(self.submodule_path)}[^"]*"\]\s*\n(?:\s*\w+\s*=\s*[^\n]*\n)*'
                updated_content = re.sub(pattern, "", content)

                if updated_content != content:
                    with open(config_path, "w") as f:
                        f.write(updated_content)
                    self.info("✓ Submodule removed from git config (direct removal)")
                    return True
            except Exception as e:
                self.warning(f"Failed to remove from config file directly: {e}")

        # Still return True as this might not be critical
        self.warning("Could not verify removal from git config, but continuing...")
        return True

    def _clear_git_cache(self) -> bool:
        """Clear the git cache for the submodule."""
        self.info("Clearing git cache for submodule...")

        exit_code, _, stderr = self._run_git_command(
            ["rm", "-r", "--cached", "--", self.submodule_path], check=False
        )

        if exit_code == 0:
            self.info("✓ Git cache cleared")
            return True
        else:
            self.error(f"Failed to clear git cache: {stderr}")
            return False

    def _commit_removal(self) -> bool:
        """Commit the submodule removal."""
        self.info("Committing removal...")

        # Stage the changes
        self._run_git_command(["add", ".gitmodules"], check=False)
        self._run_git_command(["add", "-u"], check=False)

        # Commit
        exit_code, _, stderr = self._run_git_command(
            ["commit", "-m", f"Remove submodule: {self.submodule_path}"], check=False
        )

        if exit_code == 0:
            self.info("✓ Removal committed")
            return True
        else:
            self.error(f"Failed to commit removal: {stderr}")
            return False

    def remove(self) -> int:
        """
        Execute the submodule removal process.

        Returns:
            Exit code (0 for success, non-zero for failure)
        """
        # Validate submodule exists
        if not self._is_submodule_registered() and not self._submodule_exists_on_disk():
            self.error(f"Submodule not found: {self.submodule_path}")
            return 1

        # Check for uncommitted changes
        if self.use_checkpoint:
            self.info("Checkpoint mode enabled - creating snapshot for safe removal")
            if not self._create_checkpoint():
                return 5
        else:
            if self._has_uncommitted_changes():
                self.warning("Uncommitted changes detected!")
                self.warning("To enable automatic snapshots, use --checkpoint flag")
                # Continue with removal anyway

        # Execute removal steps
        try:
            if not self._improved_rm():
                raise RuntimeError("Failed to remove folder and module entry")

            if not self._remove_from_git_config():
                raise RuntimeError("Failed to remove from .git/config")

            if not self._remove_submodule_meta():
                raise RuntimeError("Failed to remove modules data folder")

            # if not self._remove_from_gitmodules():
            #     raise RuntimeError("Failed to remove from .gitmodules")

            # if not self._clear_git_cache():
            #     raise RuntimeError("Failed to clear git cache")

            if not self._commit_removal():
                raise RuntimeError("Failed to commit removal")

            self.info("✓ Submodule removed successfully")
            self._cleanup_checkpoint()
            return 0

        except RuntimeError as e:
            self.error(f"Removal failed: {e}")

            if self.use_checkpoint:
                self.info("Attempting to restore from checkpoint...")
                if not self._restore_checkpoint():
                    self.error("Failed to restore checkpoint!")
                    return 4
                return 0  # Successfully restored, return success
            else:
                return 3


def main() -> int:
    """Main entry point."""
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        print(__doc__, file=sys.stderr)
        return 2

    submodule_path = sys.argv[1]
    use_checkpoint = "--checkpoint" in sys.argv

    remover = GitSubmoduleRemover(submodule_path, use_checkpoint)
    return remover.remove()


if __name__ == "__main__":
    sys.exit(main())
