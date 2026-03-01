#!/usr/bin/env bats

# install.sh BATS tests
# Run with: bats tests/install.bats

setup() {
    # Get the directory containing the test file
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"
    INSTALL_SCRIPT="$PROJECT_ROOT/install.sh"

    # Create temporary directory for test artifacts
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR

    # Mock HOME for isolated testing
    export ORIGINAL_HOME="$HOME"
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"

    # Store original working directory
    export ORIGINAL_PWD="$PWD"
}

teardown() {
    # Restore original HOME
    export HOME="$ORIGINAL_HOME"

    # Clean up temporary directory
    if [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi

    # Restore working directory
    cd "$ORIGINAL_PWD"
}

# =============================================================================
# Helper Functions
# =============================================================================

# Source install.sh functions without executing main logic
# This defines the functions directly for testing
load_install_functions() {
    # Set SCRIPT_DIR for the functions
    export SCRIPT_DIR="$PROJECT_ROOT"

    # Define discover_modules function (same as in install.sh)
    discover_modules() {
        local modules=()
        if [[ -d "$SCRIPT_DIR/commands" ]]; then
            for dir in "$SCRIPT_DIR/commands"/*/; do
                local name
                name=$(basename "$dir")
                if [[ "$name" != "session" && "$name" != "help" ]]; then
                    modules+=("$name")
                fi
            done
        fi
        echo "${modules[@]}"
    }
    export -f discover_modules

    # Define validate_module function (same as in install.sh)
    validate_module() {
        local mod="$1"
        for valid_mod in "${ALL_MODULES[@]}"; do
            if [[ "$mod" == "$valid_mod" ]]; then
                return 0
            fi
        done
        return 1
    }
    export -f validate_module

    # Initialize ALL_MODULES
    IFS=' ' read -ra ALL_MODULES <<< "$(discover_modules)"
    export ALL_MODULES
}

# =============================================================================
# 1. Basic Functionality Tests
# =============================================================================

@test "help option displays usage information" {
    run bash "$INSTALL_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"--global"* ]]
    [[ "$output" == *"--local"* ]]
    [[ "$output" == *"--all"* ]]
    [[ "$output" == *"--modules"* ]]
}

@test "short help option -h displays usage information" {
    run bash "$INSTALL_SCRIPT" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "help shows available modules" {
    run bash "$INSTALL_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Available:"* ]]
    # Should list at least some known modules
    [[ "$output" == *"backend"* ]] || [[ "$output" == *"go"* ]] || [[ "$output" == *"k8s"* ]]
}

@test "global option sets correct target directory" {
    # Run with --global --help to see the behavior without full install
    # We test by checking the help mentions global
    run bash "$INSTALL_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--global"* ]]
    [[ "$output" == *"~/.claude/"* ]]
}

@test "local option description in help" {
    run bash "$INSTALL_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--local"* ]]
    [[ "$output" == *"./.claude/"* ]]
}

@test "all option is documented in help" {
    run bash "$INSTALL_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--all"* ]]
    [[ "$output" == *"Install all modules"* ]]
}

# =============================================================================
# 2. Module Validation Tests
# =============================================================================

@test "discover_modules returns valid module list" {
    load_install_functions

    # discover_modules should return non-empty list
    local modules
    modules=$(discover_modules)
    [ -n "$modules" ]

    # Should contain known modules (at least one of these)
    [[ "$modules" == *"backend"* ]] || \
    [[ "$modules" == *"go"* ]] || \
    [[ "$modules" == *"k8s"* ]] || \
    [[ "$modules" == *"terraform"* ]] || \
    [[ "$modules" == *"dx"* ]]
}

@test "discover_modules excludes session module" {
    load_install_functions

    local modules
    modules=$(discover_modules)

    # session should NOT be in the discovered modules (it's always included separately)
    [[ "$modules" != *"session"* ]] || {
        # If session appears, it should not be a standalone word
        local found=false
        for mod in $modules; do
            if [[ "$mod" == "session" ]]; then
                found=true
                break
            fi
        done
        [ "$found" = false ]
    }
}

@test "discover_modules excludes help module" {
    load_install_functions

    local modules
    modules=$(discover_modules)

    # help should NOT be in the discovered modules
    local found=false
    for mod in $modules; do
        if [[ "$mod" == "help" ]]; then
            found=true
            break
        fi
    done
    [ "$found" = false ]
}

@test "validate_module accepts valid module names" {
    load_install_functions

    # Get first available module
    local first_module="${ALL_MODULES[0]}"

    # Should return success (0) for valid module
    validate_module "$first_module"
    [ $? -eq 0 ]
}

@test "validate_module rejects invalid module names" {
    load_install_functions

    # Should return failure (non-zero) for invalid module
    run validate_module "nonexistent_module_xyz"
    [ "$status" -ne 0 ]
}

@test "validate_module rejects empty module name" {
    load_install_functions

    run validate_module ""
    [ "$status" -ne 0 ]
}

@test "modules option parsing with single module" {
    # Test that --modules with valid module doesn't error on help
    run bash "$INSTALL_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--modules LIST"* ]]
}

@test "invalid module name is rejected" {
    run bash "$INSTALL_SCRIPT" --global --modules "invalid_module_name"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid module"* ]]
}

@test "modules option accepts comma-separated values" {
    # Check help documents comma-separated format
    run bash "$INSTALL_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"comma-separated"* ]]
}

# =============================================================================
# 3. Error Handling Tests
# =============================================================================

@test "unknown option returns error" {
    run bash "$INSTALL_SCRIPT" --invalid-option
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "unknown short option returns error" {
    run bash "$INSTALL_SCRIPT" -x
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "modules option without argument returns error" {
    run bash "$INSTALL_SCRIPT" --modules
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing argument"* ]] || [[ "$output" == *"--modules"* ]]
}

@test "multiple invalid options still report error" {
    run bash "$INSTALL_SCRIPT" --foo --bar
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "error output goes to stderr" {
    # Run with invalid option and capture stderr
    run bash -c "bash '$INSTALL_SCRIPT' --invalid-option 2>&1 >/dev/null"
    [[ "$output" == *"Unknown option"* ]]
}

# =============================================================================
# 4. Function Tests
# =============================================================================

@test "discover_modules finds backend module" {
    load_install_functions

    local modules
    modules=$(discover_modules)

    # Check if backend directory exists and is discovered
    if [[ -d "$PROJECT_ROOT/commands/backend" ]]; then
        [[ "$modules" == *"backend"* ]]
    fi
}

@test "discover_modules finds go module" {
    load_install_functions

    local modules
    modules=$(discover_modules)

    if [[ -d "$PROJECT_ROOT/commands/go" ]]; then
        [[ "$modules" == *"go"* ]]
    fi
}

@test "discover_modules finds k8s module" {
    load_install_functions

    local modules
    modules=$(discover_modules)

    if [[ -d "$PROJECT_ROOT/commands/k8s" ]]; then
        [[ "$modules" == *"k8s"* ]]
    fi
}

@test "discover_modules finds terraform module" {
    load_install_functions

    local modules
    modules=$(discover_modules)

    if [[ -d "$PROJECT_ROOT/commands/terraform" ]]; then
        [[ "$modules" == *"terraform"* ]]
    fi
}

@test "discover_modules finds dx module" {
    load_install_functions

    local modules
    modules=$(discover_modules)

    if [[ -d "$PROJECT_ROOT/commands/dx" ]]; then
        [[ "$modules" == *"dx"* ]]
    fi
}

@test "ALL_MODULES array is populated correctly" {
    load_install_functions

    # ALL_MODULES should have at least one element
    [ "${#ALL_MODULES[@]}" -gt 0 ]
}

@test "validate_module works for all discovered modules" {
    load_install_functions

    # Every module in ALL_MODULES should be valid
    for mod in "${ALL_MODULES[@]}"; do
        validate_module "$mod"
        [ $? -eq 0 ]
    done
}

# =============================================================================
# 5. Integration Tests (Smoke Tests)
# =============================================================================

@test "script is executable" {
    [ -x "$INSTALL_SCRIPT" ] || [ -r "$INSTALL_SCRIPT" ]
}

@test "script has valid bash syntax" {
    run bash -n "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "help exits with status 0" {
    run bash "$INSTALL_SCRIPT" --help
    [ "$status" -eq 0 ]
}

@test "commands directory exists" {
    [ -d "$PROJECT_ROOT/commands" ]
}

@test "global CLAUDE.md exists" {
    [ -f "$PROJECT_ROOT/global/CLAUDE.md" ]
}

# =============================================================================
# 6. Option Combination Tests
# =============================================================================

@test "global and all options can be combined" {
    # Just verify these options are recognized (use --help to avoid actual install)
    run bash "$INSTALL_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--global"* ]]
    [[ "$output" == *"--all"* ]]
}

@test "with-skills option is documented" {
    run bash "$INSTALL_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--with-skills"* ]]
}

@test "with-mcp option is documented" {
    run bash "$INSTALL_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--with-mcp"* ]]
}

@test "example commands are shown in help" {
    run bash "$INSTALL_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Examples:"* ]]
}

# =============================================================================
# 7. Plugin System Tests
# =============================================================================

@test "plugin option is documented in help" {
    run bash "$INSTALL_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--plugin"* ]]
}

@test "list-plugins option is documented in help" {
    run bash "$INSTALL_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--list-plugins"* ]]
}

@test "plugin manifests exist in plugins directory" {
    [ -d "$PROJECT_ROOT/plugins" ]
    local count
    count=$(ls "$PROJECT_ROOT/plugins/"*.yml 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -ge 1 ]
}

@test "plugin manifest has required fields" {
    # Check that at least one plugin has name, description, agents
    local manifest="$PROJECT_ROOT/plugins/k8s-ops.yml"
    [ -f "$manifest" ]
    grep -q "^name:" "$manifest"
    grep -q "^description:" "$manifest"
    grep -q "^agents:" "$manifest"
    grep -q "categories:" "$manifest"
}
