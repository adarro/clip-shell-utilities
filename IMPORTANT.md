# ⚠️ IMPORTANT - PLEASE READ

## AI-Generated Code Notice

**This project was created with the assistance of AI (GitHub Copilot).**

While the code has been tested with a comprehensive test suite (35+ unit tests, 14+ integration tests), you should **always read, test, and verify** this code before executing it in your environment.

## Before You Execute

### ✅ What You Should Do

1. **Read the Code**
   - Review [check-clipboard-url.sh](check-clipboard-url.sh) to understand what it does
   - Check the main logic and functions
   - Verify it matches your expectations

2. **Review the Tests**
   - Look at [test-check-clipboard-url.sh](test-check-clipboard-url.sh) to see what's being tested
   - Review [integration-test-check-clipboard-url.sh](integration-test-check-clipboard-url.sh)
   - Understand the validation rules

3. **Run the Tests**

   ```bash
   ./test-check-clipboard-url.sh              # Unit tests (35 tests)
   ./integration-test-check-clipboard-url.sh  # Integration tests (14+ tests)
   ```

4. **Test in Your Environment**
   - Copy a known URL to your clipboard
   - Run the script with `--retry-count 1` to test once:
     ```bash
     ./check-clipboard-url.sh --retry-count 1 --wait-time 1
     ```
   - Verify the behavior matches what's documented

5. **Check Dependencies**
   - Ensure you have required clipboard tools installed
   - Verify your browser launcher is available
   - See [Requirements](README.md#requirements) for details

### ❌ What You Should NOT Do

- ❌ Do NOT execute scripts you haven't reviewed
- ❌ Do NOT skip the test suite
- ❌ Do NOT run with `-1` (infinite retries) on an unfamiliar system without testing first
- ❌ Do NOT use sensitive or critical data in clipboard for testing

## Warranty Disclaimer

These scripts are provided **"as is"** without warranty of any kind, express or implied. The author is not liable for any damage, loss of data, or other consequences arising from the use of these scripts.

## Security Considerations

1. **Clipboard Access** - This script reads from your system clipboard. Ensure no sensitive data is present.
2. **URL Opening** - This script opens URLs in your default browser. Only URLs you explicitly place in the clipboard will be opened.
3. **File System Access** - In local mode (`--local`), the script accesses directories. It validates readability before opening.
4. **PowerShell (WSL)** - In WSL environments, the script uses PowerShell for clipboard access. Ensure you trust your PowerShell installation.

## Testing Results

The test suite validates:

- ✓ 35 unit tests covering all functions
- ✓ 14+ integration tests with real system calls
- ✓ URL validation (valid/invalid scenarios)
- ✓ Directory validation
- ✓ Retry logic and timing
- ✓ WSL environment support
- ✓ Argument parsing and error handling

**However**, these tests were run in a **specific environment** (WSL on Windows). Your environment may differ.

## Getting Help

1. **Read the Documentation** → See [README.md](README.md) for comprehensive documentation
2. **Review the Code** → Look at the comments and functions in the main script
3. **Run the Tests** → `just test-all` or run individual test files
4. **Check Troubleshooting** → See [Troubleshooting section](README.md#troubleshooting) in README.md

## Your Responsibility

By using these scripts, you acknowledge that:

- You have read and understood this notice
- You have reviewed the code
- You have run the tests in your environment
- You understand the security implications
- You accept full responsibility for any consequences

## Questions or Concerns?

Before running these scripts:

1. Understand what the code does
2. Verify it works in your environment with tests
3. Ensure you trust the clipboard input source
4. Check that required tools are installed and working

**If you're not comfortable with any of these steps, DO NOT use these scripts.**

---

For full details, see [README.md](README.md)
