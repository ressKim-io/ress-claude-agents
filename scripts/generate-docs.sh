#!/usr/bin/env bash
# generate-docs.sh - Documentation generation and validation script
# shellcheck disable=SC2155

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly COMMANDS_DIR="${PROJECT_ROOT}/commands"
readonly MANIFEST_FILE="${COMMANDS_DIR}/manifest.yml"
readonly HELP_INDEX_FILE="${COMMANDS_DIR}/help/index.md"

readonly REQUIRED_SECTIONS=("Contract" "Checklist" "Output Format" "Usage")

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    local missing_deps=()

    if ! command -v yq &>/dev/null; then
        missing_deps+=("yq")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install with: brew install ${missing_deps[*]}"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Parse manifest.yml
# -----------------------------------------------------------------------------

get_categories() {
    yq -r '.categories | keys | .[]' "${MANIFEST_FILE}"
}

get_category_title() {
    local category="$1"
    yq -r ".categories.${category}.title // \"${category}\"" "${MANIFEST_FILE}"
}

get_category_description() {
    local category="$1"
    yq -r ".categories.${category}.description // \"\"" "${MANIFEST_FILE}"
}

get_category_icon() {
    local category="$1"
    yq -r ".categories.${category}.icon // \"\"" "${MANIFEST_FILE}"
}

get_commands_by_category() {
    local category="$1"
    yq -r ".commands[] | select(.category == \"${category}\") | .id" "${MANIFEST_FILE}"
}

get_command_title() {
    local cmd_id="$1"
    yq -r ".commands[] | select(.id == \"${cmd_id}\") | .title" "${MANIFEST_FILE}"
}

get_command_description() {
    local cmd_id="$1"
    yq -r ".commands[] | select(.id == \"${cmd_id}\") | .description" "${MANIFEST_FILE}"
}

get_all_command_ids() {
    yq -r '.commands[].id' "${MANIFEST_FILE}"
}

# -----------------------------------------------------------------------------
# generate_help_index() - Generate commands/help/index.md
# -----------------------------------------------------------------------------

generate_help_index() {
    log_info "Generating help index: ${HELP_INDEX_FILE}"

    local output=""
    output+="# ress-claude-agents Help\n\n"
    output+="사용 가능한 명령어 목록입니다.\n\n"

    local categories
    categories=$(get_categories)

    for category in ${categories}; do
        local title description
        title=$(get_category_title "${category}")
        description=$(get_category_description "${category}")

        output+="## ${title}\n\n"
        output+="${description}\n\n"
        output+="| 명령어 | 설명 |\n"
        output+="|--------|------|\n"

        local commands
        commands=$(get_commands_by_category "${category}")

        for cmd_id in ${commands}; do
            local cmd_name cmd_desc
            # Convert id to command name: go-review -> review, k8s-validate -> validate
            cmd_name="${cmd_id#"${category}-"}"
            cmd_desc=$(get_command_description "${cmd_id}")

            output+="| \`/${category} ${cmd_name}\` | ${cmd_desc} |\n"
        done

        output+="\n---\n\n"
    done

    # Add detailed help section
    output+="## 상세 도움말\n\n"
    output+="\`\`\`\n"
    for category in ${categories}; do
        local title
        title=$(get_category_title "${category}")
        output+="/help ${category}    # ${title} 명령어\n"
    done
    output+="\`\`\`\n\n"

    # Add installation section
    output+="---\n\n"
    output+="## 설치\n\n"
    output+="\`\`\`bash\n"
    output+="./install.sh --global --all      # 전역 설치\n"
    output+="./install.sh --local --modules go,k8s  # 로컬 설치\n"
    output+="./install.sh                     # 대화형 설치\n"
    output+="\`\`\`\n"

    echo -e "${output}" > "${HELP_INDEX_FILE}"
    log_success "Generated ${HELP_INDEX_FILE}"
}

# -----------------------------------------------------------------------------
# validate_consistency() - Validate consistency between manifest and files
# -----------------------------------------------------------------------------

validate_consistency() {
    log_info "Validating consistency..."

    local errors=0
    local warnings=0

    # Check if manifest exists
    if [[ ! -f "${MANIFEST_FILE}" ]]; then
        log_error "Manifest file not found: ${MANIFEST_FILE}"
        return 1
    fi

    local command_ids
    command_ids=$(get_all_command_ids)

    for cmd_id in ${command_ids}; do
        local category cmd_name file_path
        category=$(yq -r ".commands[] | select(.id == \"${cmd_id}\") | .category" "${MANIFEST_FILE}")
        cmd_name="${cmd_id#"${category}-"}"
        file_path="${COMMANDS_DIR}/${category}/${cmd_name}.md"

        # Check if file exists
        if [[ ! -f "${file_path}" ]]; then
            log_error "Missing file for command '${cmd_id}': ${file_path}"
            errors=$((errors + 1))
            continue
        fi

        # Check required sections
        for section in "${REQUIRED_SECTIONS[@]}"; do
            if ! grep -q "^## ${section}" "${file_path}"; then
                log_warning "Missing section '${section}' in ${file_path}"
                warnings=$((warnings + 1))
            fi
        done
    done

    # Check for orphan files (files without manifest entry)
    local categories
    categories=$(get_categories)

    for category in ${categories}; do
        local category_dir="${COMMANDS_DIR}/${category}"
        if [[ -d "${category_dir}" ]]; then
            for file in "${category_dir}"/*.md; do
                if [[ -f "${file}" ]]; then
                    local filename cmd_name expected_id
                    filename=$(basename "${file}")
                    cmd_name="${filename%.md}"
                    expected_id="${category}-${cmd_name}"

                    if ! yq -e ".commands[] | select(.id == \"${expected_id}\")" "${MANIFEST_FILE}" &>/dev/null; then
                        log_warning "Orphan file (not in manifest): ${file}"
                        warnings=$((warnings + 1))
                    fi
                fi
            done
        fi
    done

    # Summary
    echo ""
    log_info "Validation Summary:"
    echo "  Errors:   ${errors}"
    echo "  Warnings: ${warnings}"

    if [[ ${errors} -gt 0 ]]; then
        log_error "Validation failed with ${errors} error(s)"
        return 1
    fi

    if [[ ${warnings} -gt 0 ]]; then
        log_warning "Validation completed with ${warnings} warning(s)"
    else
        log_success "Validation passed"
    fi

    return 0
}

# -----------------------------------------------------------------------------
# generate_command_summary() - Generate command statistics
# -----------------------------------------------------------------------------

generate_command_summary() {
    log_info "Generating command summary..."

    echo ""
    echo "======================================"
    echo "        Command Summary"
    echo "======================================"
    echo ""

    local total_commands=0
    local categories
    categories=$(get_categories)

    printf "%-15s %-30s %s\n" "Category" "Title" "Commands"
    printf "%-15s %-30s %s\n" "--------" "-----" "--------"

    for category in ${categories}; do
        local title count
        title=$(get_category_title "${category}")
        count=$(get_commands_by_category "${category}" | wc -l | tr -d ' ')

        printf "%-15s %-30s %s\n" "${category}" "${title}" "${count}"
        ((total_commands += count))
    done

    echo ""
    echo "--------------------------------------"
    printf "%-15s %-30s %s\n" "TOTAL" "" "${total_commands}"
    echo "======================================"

    # Additional statistics
    echo ""
    log_info "Additional Statistics:"

    local files_count
    files_count=$(find "${COMMANDS_DIR}" -name "*.md" -not -path "*/help/*" | wc -l | tr -d ' ')
    echo "  Command files:     ${files_count}"

    local categories_count
    categories_count=$(get_categories | wc -l | tr -d ' ')
    echo "  Categories:        ${categories_count}"

    local help_files_count
    help_files_count=$(find "${COMMANDS_DIR}/help" -name "*.md" | wc -l | tr -d ' ')
    echo "  Help files:        ${help_files_count}"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: $(basename "$0") [COMMAND]

Commands:
  help-index    Generate commands/help/index.md from manifest.yml
  validate      Validate consistency between manifest and files
  summary       Generate command statistics
  all           Run all tasks (default)

Options:
  -h, --help    Show this help message

Examples:
  $(basename "$0")              # Run all tasks
  $(basename "$0") help-index   # Generate help index only
  $(basename "$0") validate     # Validate only
  $(basename "$0") summary      # Show summary only
EOF
}

main() {
    local command="${1:-all}"

    case "${command}" in
        -h|--help)
            usage
            exit 0
            ;;
        help-index)
            check_dependencies
            generate_help_index
            ;;
        validate)
            check_dependencies
            validate_consistency
            ;;
        summary)
            check_dependencies
            generate_command_summary
            ;;
        all)
            check_dependencies
            generate_help_index
            echo ""
            validate_consistency
            echo ""
            generate_command_summary
            ;;
        *)
            log_error "Unknown command: ${command}"
            usage
            exit 1
            ;;
    esac
}

main "$@"
