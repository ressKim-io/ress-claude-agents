# Tests for ress-claude-agents

This directory contains BATS (Bash Automated Testing System) tests for the install script and other shell components.

## Prerequisites

### Installing BATS

**macOS (Homebrew):**
```bash
brew install bats-core
```

**Ubuntu/Debian:**
```bash
sudo apt-get install bats
```

**From source:**
```bash
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local
```

## Running Tests

### Run all tests
```bash
# From project root
bats tests/

# Or with verbose output
bats --verbose-run tests/
```

### Run specific test file
```bash
bats tests/install.bats
```

### Run with TAP output (for CI)
```bash
bats --tap tests/install.bats
```

### Run specific test by name
```bash
bats --filter "help option" tests/install.bats
```

## Test Structure

### install.bats

Tests for `install.sh` covering:

1. **Basic Functionality Tests**
   - `--help` option displays usage information
   - `--global` and `--local` options documentation
   - `--all` option behavior

2. **Module Validation Tests**
   - `discover_modules()` returns valid module list
   - `validate_module()` accepts/rejects modules correctly
   - `--modules` option parsing

3. **Error Handling Tests**
   - Unknown options return errors
   - Missing arguments are detected
   - Error messages go to stderr

4. **Function Tests**
   - `discover_modules()` finds all expected modules
   - `validate_module()` works for all discovered modules
   - Module exclusions (session, help) work correctly

5. **Integration Tests**
   - Script syntax validation
   - Required files exist
   - Script is executable

## Writing New Tests

### Test file template
```bash
#!/usr/bin/env bats

setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"
}

teardown() {
    # Cleanup code here
}

@test "description of test" {
    run some_command
    [ "$status" -eq 0 ]
    [[ "$output" == *"expected string"* ]]
}
```

### Common assertions
```bash
# Check exit status
[ "$status" -eq 0 ]       # Success
[ "$status" -ne 0 ]       # Failure

# Check output contains string
[[ "$output" == *"text"* ]]

# Check output equals exactly
[ "$output" = "exact text" ]

# Check file exists
[ -f "$filepath" ]

# Check directory exists
[ -d "$dirpath" ]
```

## CI Integration

### GitHub Actions example
```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install BATS
        run: |
          sudo apt-get update
          sudo apt-get install -y bats

      - name: Run tests
        run: bats --tap tests/
```

## Troubleshooting

### Tests fail with "command not found"
Ensure BATS is installed and in your PATH:
```bash
which bats
bats --version
```

### Tests hang during interactive prompts
The tests are designed to avoid interactive mode by using `--help` or specific flags. If a test hangs, check that it's not triggering interactive prompts.

### Temporary files not cleaned up
Check that teardown() is properly implemented. Use `TEST_TEMP_DIR` for any temporary files.
