# Makefile for ress-claude-agents
# Claude Code Custom Commands & Skills Management

.PHONY: help test validate generate inventory lint install-global install-local setup-hooks clean all

# Default target
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@echo "  help           Show this help message (default)"
	@echo "  test           Run BATS tests"
	@echo "  validate       Validate documentation consistency"
	@echo "  generate       Generate documentation (help/index.md)"
	@echo "  inventory      Generate .claude/inventory.yml"
	@echo "  lint           Run shellcheck on shell scripts"
	@echo "  install-global Install commands globally (~/.claude)"
	@echo "  install-local  Install commands to current project"
	@echo "  setup-hooks    Setup pre-commit git hooks"
	@echo "  clean          Remove generated files"
	@echo "  all            Run validate and test"

# Run BATS tests
test:
	@echo "Running BATS tests..."
	@if command -v bats >/dev/null 2>&1; then \
		bats tests/*.bats; \
	else \
		echo "Error: bats is not installed. Install with: brew install bats-core"; \
		exit 1; \
	fi

# Validate documentation consistency
validate:
	@echo "Validating documentation..."
	@./scripts/generate-docs.sh validate

# Generate documentation
generate:
	@echo "Generating documentation..."
	@./scripts/generate-docs.sh generate

# Generate inventory
inventory:
	@echo "Generating inventory..."
	@./scripts/generate-inventory.sh generate

# Run shellcheck on shell scripts
lint:
	@echo "Running shellcheck..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		find . -name "*.sh" -type f -not -path "./.git/*" -exec shellcheck {} +; \
		echo "Shellcheck completed successfully."; \
	else \
		echo "Error: shellcheck is not installed. Install with: brew install shellcheck"; \
		exit 1; \
	fi

# Install globally
install-global:
	@echo "Installing globally..."
	@./install.sh --global

# Install locally
install-local:
	@echo "Installing locally..."
	@./install.sh --local

# Setup pre-commit hooks
setup-hooks:
	@echo "Setting up pre-commit hooks..."
	@mkdir -p .git/hooks
	@echo '#!/bin/bash' > .git/hooks/pre-commit
	@echo 'make validate' >> .git/hooks/pre-commit
	@echo 'make lint' >> .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "Pre-commit hook installed successfully."

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	@rm -f commands/help/index.md
	@echo "Clean completed."

# Run all checks
all: validate test
	@echo "All checks completed."
