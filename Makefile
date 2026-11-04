# Makefile for ress-claude-agents
# Claude Code Custom Commands & Skills Management

.PHONY: help validate validate-enforcement validate-links validate-yaml test-gates verify-enforcement plugin-readmes verify-plugins inventory lint setup-hooks all

# Default target
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@echo "  help           Show this help message (default)"
	@echo "  validate       Validate asset catalog (floors, locations, command refs)"
	@echo "  validate-enforcement  Check settings.json <-> user-approval.md rule drift (static, CI)"
	@echo "  validate-links        Check internal markdown links resolve"
	@echo "  validate-yaml         Parse all frontmatter with a real YAML parser (needs control-plane npm ci)"
	@echo "  test-gates            Break a copy of the repo and check each gate fails for the right reason"
	@echo "  verify-enforcement    Check permission rules actually fire (runtime, needs claude CLI)"
	@echo "  inventory      Generate .claude/inventory.yml"
	@echo "  plugin-readmes Generate plugins/*/README.md from frontmatter"
	@echo "  verify-plugins Validate manifests with the claude CLI (local only, no model calls)"
	@echo "  lint           Run shellcheck on shell scripts"
	@echo "  setup-hooks    Setup pre-commit git hooks"
	@echo "  all            Run validate + enforcement + links"

# Validate asset catalog
validate:
	@./scripts/validate-catalog.sh

# 강제 규칙 정적 검증 (CI 에서도 돈다)
validate-enforcement:
	@./scripts/validate-enforcement.sh

# 내부 마크다운 링크 검증 (CI 에서도 돈다)
validate-links:
	@./scripts/validate-links.sh

# frontmatter YAML 검증 (CI 에서도 돈다)
validate-yaml:
	@node scripts/validate-frontmatter-yaml.mjs

# 게이트 자체 검증: 레포 사본을 망가뜨려 각 게이트가 의도한 사유로 실패하는지 본다 (CI 에서도 돈다)
test-gates:
	@./scripts/test-gates.sh

# 강제 규칙 런타임 검증 — claude CLI 와 계정 인증이 필요해 CI 에서 돌지 않는다.
# 규칙을 추가·변경한 커밋에서 1회 실행한다 (ADR 0009 §Consequences).
verify-enforcement:
	@./scripts/verify-enforcement-runtime.sh

# Generate inventory
inventory:
	@echo "Generating inventory..."
	@./scripts/generate-inventory.sh generate

# plugin README 생성 (CI 가 신선도를 검사한다)
plugin-readmes:
	@python3 scripts/generate-plugin-readmes.py generate

# claude CLI 로 매니페스트 검증. version 은 일부러 비워 두므로 --strict 대신 경고를 걸러 본다 (ADR 0012)
verify-plugins:
	@./scripts/verify-plugins.sh

# Run shellcheck on shell scripts
lint:
	@echo "Running shellcheck..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		find . -name "*.sh" -type f -not -path "./.git/*" -exec shellcheck {} + && \
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

# Run all checks
all: validate validate-enforcement validate-links
	@echo "All checks completed."
