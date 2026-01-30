#!/usr/bin/env bash
# setup-hooks.sh - Configure git hooks for the repository
# Usage: ./scripts/setup-hooks.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT
readonly HOOKS_DIR="${PROJECT_ROOT}/.githooks"

# Colors for output
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

main() {
    echo ""
    log_info "Setting up git hooks..."
    echo ""

    # Check if .githooks directory exists
    if [[ ! -d "${HOOKS_DIR}" ]]; then
        echo "Error: .githooks directory not found"
        exit 1
    fi

    # Configure git to use .githooks directory
    log_info "Configuring git hooks path..."
    git -C "${PROJECT_ROOT}" config core.hooksPath .githooks

    # Make hooks executable
    log_info "Setting executable permissions..."
    chmod +x "${HOOKS_DIR}"/*

    echo ""
    log_success "Git hooks configured successfully!"
    echo ""
    echo "Hooks directory: .githooks/"
    echo "Active hooks:"
    for hook in "${HOOKS_DIR}"/*; do
        if [[ -f "${hook}" ]]; then
            echo "  - $(basename "${hook}")"
        fi
    done
    echo ""
    echo "To disable hooks temporarily, use: git commit --no-verify"
    echo ""
}

main "$@"
