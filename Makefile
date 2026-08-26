# Makefile for ress-claude-agents
# Claude Code Custom Commands & Skills Management

.PHONY: help validate validate-enforcement validate-links verify-enforcement generate inventory lint setup-hooks clean all

# Default target
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@echo "  help           Show this help message (default)"
	@echo "  validate       Validate documentation consistency"
	@echo "  validate-enforcement  Check settings.json <-> user-approval.md rule drift (static, CI)"
	@echo "  validate-links        Check internal markdown links resolve"
	@echo "  verify-enforcement    Check permission rules actually fire (runtime, needs claude CLI)"
	@echo "  generate       Generate documentation (help/index.md)"
	@echo "  inventory      Generate .claude/inventory.yml"
	@echo "  lint           Run shellcheck on shell scripts"
	@echo "  setup-hooks    Setup pre-commit git hooks"
	@echo "  clean          Remove generated files"
	@echo "  all            Run validate + enforcement + links"

# Validate documentation consistency
validate:
	@echo "Validating documentation..."
	@./scripts/generate-docs.sh validate

# 강제 규칙 정적 검증 (CI 에서도 돈다)
validate-enforcement:
	@./scripts/validate-enforcement.sh

# 내부 마크다운 링크 검증 (CI 에서도 돈다)
validate-links:
	@./scripts/validate-links.sh

# 강제 규칙 런타임 검증 — claude CLI 와 계정 인증이 필요해 CI 에서 돌지 않는다.
# 규칙을 추가·변경한 커밋에서 1회 실행한다 (ADR 0009 §Consequences).
verify-enforcement:
	@./scripts/verify-enforcement-runtime.sh

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
all: validate validate-enforcement validate-links
	@echo "All checks completed."
