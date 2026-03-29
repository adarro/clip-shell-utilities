# check-clipboard-url

A bash script that monitors your clipboard for valid URLs or local directory paths and automatically opens them in your default browser or file manager.

## Features

- ✅ **URL Validation** - Detects valid HTTP/HTTPS URLs and domain names
- ✅ **Local Directory Support** - Detect and open local file paths (via `--local` mode)
- ✅ **Configurable Retries** - Set custom retry count or use infinite loop mode (`-1`)
- ✅ **Configurable Wait Time** - Control delay between retry attempts (minimum: 1 second)
- ✅ **WSL Support** - Works in Windows Subsystem for Linux via PowerShell clipboard
- ✅ **Cross-Platform** - Supports Linux, macOS, and WSL environments
- ✅ **Clipboard Detection** - Automatically uses xclip, xsel, pbpaste, or PowerShell
- ✅ **Comprehensive Testing** - 35+ unit tests + 14+ integration tests
- ✅ **Easy Task Management** - Justfile with 25+ recipes for common operations

## Requirements

### Clipboard Tools

One of the following must be installed:

- **Linux**: `xclip` or `xsel`
- **macOS**: `pbpaste` (built-in)
- **WSL**: `powershell.exe` (Windows binary accessible from WSL)

### Browser Launcher

One of the following must be available:

- **Linux**: `xdg-open` (usually pre-installed)
- **macOS**: `open` (built-in)

### Optional

- `just` - Task runner for convenient recipe execution ([install here](https://github.com/casey/just))
- `shellcheck` - Shell script linter (for code analysis)

## Installation

### Quick Setup

```bash
# Clone or download the scripts
cd /path/to/scriptutil

# Make scripts executable
chmod +x check-clipboard-url.sh
chmod +x test-check-clipboard-url.sh
chmod +x integration-test-check-clipboard-url.sh

# Verify tests pass
./test-check-clipboard-url.sh
```

### Using Just

```bash
# Setup all scripts at once
just setup

# View all available recipes
just --list

# Show quick usage guide
just usage
```

## Usage

### Basic Commands

```bash
# Open URL from clipboard (default: 5 retries, 2s wait)
./check-clipboard-url.sh

# Open directory from clipboard
./check-clipboard-url.sh --local
./check-clipboard-url.sh -l

# Custom retry count
./check-clipboard-url.sh --retry-count 10
./check-clipboard-url.sh --retry-count -1    # infinite retries

# Custom wait time
./check-clipboard-url.sh --wait-time 5       # 5 seconds between attempts

# Combine options
./check-clipboard-url.sh --local --retry-count -1 --wait-time 3
```

### Using Just Recipes

```bash
# Core functionality
just url                              # Check URL (default)
just local                            # Check directory
just url-retry 10                     # Custom retry count
just url-wait 5                       # Custom wait time
just url-infinite                     # Infinite loop mode
just local-infinite                   # Local mode infinite

# Testing
just test                             # Run unit tests
just test-integration                 # Run integration tests
just test-all                         # Run all tests
just test-quick                       # Quick test preview

# Demos
just demo                             # Demo with example URL
just demo-local                       # Demo with test directory

# Serve
just serve                            # Serve with npx serve (uses HTTP_SERVE env var)
just serve <path>                     # Serve specific directory

# Utilities
just usage                            # Show quick reference
just info                             # Show script info
just setup                            # Make scripts executable
just lint                             # ShellCheck analysis
```

## Examples

### Example 1: Open URL from Clipboard

```bash
# Copy a URL to clipboard first
# (e.g., highlight a URL and Ctrl+C)

# Then run
./check-clipboard-url.sh

# Output:
# Valid URL found: https://github.com/user/repo
# Opening URL in default browser...
```

### Example 2: Open Directory in File Manager

```bash
# Copy a directory path to clipboard
echo "/home/user/documents" | xclip -selection clipboard

# Run in local mode
./check-clipboard-url.sh --local

# Output:
# Valid directory found: /home/user/documents
# Opening directory in file manager...
```

### Example 3: Infinite Retry Mode

```bash
# Wait indefinitely for a valid URL
./check-clipboard-url.sh --retry-count -1 --wait-time 2

# Will keep checking clipboard every 2 seconds
# Press Ctrl+C to stop
```

### Example 4: Using a Just Recipe

```bash
# Navigate to the scriptutil directory
cd /path/to/scriptutil

# Use just recipe to open URL
just url

# Or run tests
just test-all
```

## Command Options

```bash
Usage: ./check-clipboard-url.sh [OPTIONS]

Options:
  --retry-count N       Number of retries before giving up
                        - Positive integer: retry that many times
                        - -1: infinite retries (press Ctrl+C to exit)

  --wait-time N         Seconds to wait between retry attempts
                        - Must be >= 1 second (minimum enforced)

  --local, -l           Treat clipboard as local directory path
                        - Validates directory exists and is readable
                        - Supports tilde (~) expansion to home directory
                        - Opens in file manager instead of browser

Examples:
  ./check-clipboard-url.sh                              # defaults
  ./check-clipboard-url.sh --retry-count 10 --wait-time 3
  ./check-clipboard-url.sh --local -retry-count -1      # infinite local
  ./check-clipboard-url.sh -l --wait-time 2             # short form
```

## URL Validation Rules

Valid URLs must match one of these patterns:

1. **Explicit Protocol**
   - `https://www.example.com`
   - `http://localhost:8080`
   - `https://github.com/user/repo`

2. **Domain Name** (requires at least one dot)
   - `www.example.com`
   - `example.com`
   - `github.com`

Invalid URLs:

- `example` (no TLD)
- `just-text` (no domain)
- `ftp://example.com` (unsupported protocol)
- `-example.com` (starts with hyphen)

## Directory Validation Rules (Local Mode)

Valid directories must:

- Exist on the filesystem
- Be readable by the current user
- Be an actual directory (not a file)

Supports tilde expansion:

- `~` → `/home/username`
- `~/documents` → `/home/username/documents`

## Testing

### Run Unit Tests

```bash
./test-check-clipboard-url.sh

# Output:
# Tests run:    35
# Tests passed: 35
# Tests failed: 0
```

### Run Integration Tests

```bash
./integration-test-check-clipboard-url.sh

# Tests actual clipboard and browser functionality
```

### Run All Tests

```bash
just test-all
```

### Test Coverage

#### Unit Tests

35 tests

- URL validation (valid and invalid URLs)
- Browser protocol handling
- WSL environment detection
- Argument validation
- Infinite loop mode
- Local mode directory validation
- Option parsing

#### Integration Tests

14+ tests

- Clipboard tool detection
- Browser launcher detection
- Clipboard read/write operations
- Empty clipboard handling
- Retry timing validation
- Local mode directory access

## Architecture

### Files

- `check-clipboard-url.sh` - Main script (executable)
- `test-check-clipboard-url.sh` - Unit test suite
- `integration-test-check-clipboard-url.sh` - Integration tests
- `justfile` - Task definitions (20+ recipes)
- `README.md` - This file
- `LICENSE` - Apache 2.0 license

### Key Functions

**Main Script**

- `is_wsl()` - Detect WSL environment
- `is_valid_url()` - Validate URL format
- `is_valid_directory()` - Validate directory path
- `get_clipboard()` - Read from system clipboard
- `open_browser()` - Open URL/directory in default app

## Environment Support

| Environment     | Clipboard Tool | Browser Launcher | Status            |
| --------------- | -------------- | ---------------- | ----------------- |
| Linux (Desktop) | xclip/xsel     | xdg-open         | ✓ Fully supported |
| Linux (Server)  | none           | none             | ⚠ Requires setup  |
| macOS           | pbpaste        | open             | ✓ Fully supported |
| WSL (Windows)   | powershell.exe | xdg-open         | ✓ Fully supported |
| Container       | depends        | depends          | ⚠ Case-by-case    |

## Troubleshooting

### "Error: Could not access clipboard"

- **Linux**: Install `xclip` (`sudo apt-get install xclip`) or `xsel`
- **macOS**: Verify `pbpaste` is available (should be built-in)
- **WSL**: Ensure `powershell.exe` is in PATH (usually automatic)

### "Error: No browser launcher found"

- **Linux**: Install `xdg-open` (usually pre-installed, or try `sudo apt-get install xdg-utils`)
- **macOS**: Verify `open` is available (should be built-in)

### "Pattern not found" or script exits immediately

- Ensure clipboard contains valid URL or directory path
- Check clipboard content: `xclip -selection clipboard -o` (Linux) or `powershell.exe -command Get-Clipboard` (WSL)

## Contributing

The project includes comprehensive tests. When adding features:

1. Add unit tests to `test-check-clipboard-url.sh`
2. Add integration tests to `integration-test-check-clipboard-url.sh`
3. Run `just test-all` to verify everything passes
4. Optionally run `just lint` if ShellCheck is installed

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

## Author

Andre White [github](https://github.com/adarro)
Created as a utility script for clipboard management and automation.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.
