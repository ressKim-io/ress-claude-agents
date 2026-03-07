#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# State tracking
declare -a INSTALLED_COMPONENTS=()
declare -a BACKUP_FILES=()
INSTALL_SUCCESS=true

# Discover available modules from commands directory (excluding session and help)
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

# Read modules dynamically
IFS=' ' read -ra ALL_MODULES <<< "$(discover_modules)"

# Logging functions
log_info() {
    echo -e "${GREEN}$1${NC}"
}

log_warn() {
    echo -e "${YELLOW}$1${NC}"
}

log_error() {
    echo -e "${RED}$1${NC}" >&2
}

log_section() {
    echo -e "${BLUE}$1${NC}"
}

# Error handler (called by trap)
# shellcheck disable=SC2329,SC2317
handle_error() {
    local line_no=$1
    log_error "Error occurred at line $line_no"
    INSTALL_SUCCESS=false
}

trap 'handle_error ${LINENO}' ERR

# Backup and link/copy a file or directory
# Usage: backup_and_link <source> <target> <scope> <type>
# type: "file" or "dir"
backup_and_link() {
    local source="$1"
    local target="$2"
    local scope="$3"
    local type="${4:-file}"

    # Validate source exists
    if [[ "$type" == "file" && ! -f "$source" ]]; then
        log_error "Source file not found: $source"
        return 1
    elif [[ "$type" == "dir" && ! -d "$source" ]]; then
        log_error "Source directory not found: $source"
        return 1
    fi

    # Handle existing target
    if [[ -L "$target" ]]; then
        rm "$target" || {
            log_error "Failed to remove existing symlink: $target"
            return 1
        }
    elif [[ -e "$target" ]]; then
        local backup="${target}.backup"
        log_info "  Backing up existing: $(basename "$target")"
        mv "$target" "$backup" || {
            log_error "Failed to backup: $target"
            return 1
        }
        BACKUP_FILES+=("$backup")
    fi

    # Create link or copy based on scope
    if [[ "$scope" == "global" ]]; then
        ln -s "$source" "$target" || {
            log_error "Failed to create symlink: $target"
            return 1
        }
        echo "  -> Linked: $target"
    else
        if [[ "$type" == "dir" ]]; then
            cp -r "$source" "$target" || {
                log_error "Failed to copy directory: $target"
                return 1
            }
        else
            cp "$source" "$target" || {
                log_error "Failed to copy file: $target"
                return 1
            }
        fi
        echo "  -> Copied: $target"
    fi

    # Verify target was created
    if [[ ! -e "$target" ]]; then
        log_error "Target was not created: $target"
        return 1
    fi

    return 0
}

# Create directory with verification
create_dir() {
    local dir="$1"
    mkdir -p "$dir" || {
        log_error "Failed to create directory: $dir"
        return 1
    }
    if [[ ! -d "$dir" ]]; then
        log_error "Directory was not created: $dir"
        return 1
    fi
}

# Validate module name
validate_module() {
    local mod="$1"
    for valid_mod in "${ALL_MODULES[@]}"; do
        if [[ "$mod" == "$valid_mod" ]]; then
            return 0
        fi
    done
    return 1
}

# Resolve plugin manifest to agent and skill category lists
resolve_plugin() {
    local plugin_name="$1"
    local manifest="$SCRIPT_DIR/plugins/${plugin_name}.yml"

    if [[ ! -f "$manifest" ]]; then
        log_error "Plugin not found: $plugin_name"
        log_error "Available plugins: $(find "$SCRIPT_DIR/plugins/" -name '*.yml' -print0 2>/dev/null | xargs -0 -I{} basename {} .yml | tr '\n' ', ')"
        exit 1
    fi

    # Parse agents from YAML (simple grep-based parsing)
    PLUGIN_AGENTS=()
    PLUGIN_SKILL_CATEGORIES=()
    local in_agents=false
    local in_categories=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^agents: ]]; then
            in_agents=true
            in_categories=false
            continue
        elif [[ "$line" =~ ^skills: ]]; then
            in_agents=false
            continue
        elif [[ "$line" =~ ^[[:space:]]+categories: ]]; then
            in_categories=true
            in_agents=false
            continue
        elif [[ "$line" =~ ^[a-z] && ! "$line" =~ ^[[:space:]] ]]; then
            in_agents=false
            in_categories=false
        fi

        if [[ "$in_agents" == true && "$line" =~ ^[[:space:]]+-[[:space:]]+(.*) ]]; then
            PLUGIN_AGENTS+=("${BASH_REMATCH[1]}")
        elif [[ "$in_categories" == true && "$line" =~ ^[[:space:]]+-[[:space:]]+(.*) ]]; then
            PLUGIN_SKILL_CATEGORIES+=("${BASH_REMATCH[1]}")
        fi
    done < "$manifest"
}

# Resolve workflow manifest to merged agent, skill, and rule lists
# Loads _base.yml first, then merges the scenario workflow
resolve_workflow() {
    local workflow_name="$1"
    local workflow_file="$SCRIPT_DIR/.claude/workflows/${workflow_name}.yml"
    local base_file="$SCRIPT_DIR/.claude/workflows/_base.yml"

    if [[ ! -f "$workflow_file" ]]; then
        log_error "Workflow not found: $workflow_name"
        log_error "Available workflows: $(find "$SCRIPT_DIR/.claude/workflows/" -name '*.yml' ! -name '_base.yml' -print0 2>/dev/null | xargs -0 -I{} basename {} .yml | tr '\n' ', ')"
        exit 1
    fi

    WORKFLOW_AGENTS=()
    WORKFLOW_SKILL_CATEGORIES=()
    WORKFLOW_SKILL_INDIVIDUAL=()
    WORKFLOW_RULES=()

    # Parse a single workflow YAML file into temp arrays
    _parse_workflow_yaml() {
        local file="$1"
        local in_agents=false
        local in_categories=false
        local in_individual=false
        local in_rules=false

        while IFS= read -r line; do
            if [[ "$line" =~ ^agents: ]]; then
                in_agents=true; in_categories=false; in_individual=false; in_rules=false
                continue
            elif [[ "$line" =~ ^skills: ]]; then
                in_agents=false; in_categories=false; in_individual=false; in_rules=false
                continue
            elif [[ "$line" =~ ^[[:space:]]+categories: ]]; then
                in_categories=true; in_agents=false; in_individual=false; in_rules=false
                continue
            elif [[ "$line" =~ ^[[:space:]]+individual: ]]; then
                in_individual=true; in_agents=false; in_categories=false; in_rules=false
                continue
            elif [[ "$line" =~ ^rules: ]]; then
                in_rules=true; in_agents=false; in_categories=false; in_individual=false
                continue
            elif [[ "$line" =~ ^[a-z] && ! "$line" =~ ^[[:space:]] ]]; then
                in_agents=false; in_categories=false; in_individual=false; in_rules=false
            fi

            if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.*) ]]; then
                local val="${BASH_REMATCH[1]}"
                if [[ "$in_agents" == true ]]; then
                    WORKFLOW_AGENTS+=("$val")
                elif [[ "$in_categories" == true ]]; then
                    WORKFLOW_SKILL_CATEGORIES+=("$val")
                elif [[ "$in_individual" == true ]]; then
                    WORKFLOW_SKILL_INDIVIDUAL+=("$val")
                elif [[ "$in_rules" == true ]]; then
                    WORKFLOW_RULES+=("$val")
                fi
            fi
        done < "$file"
    }

    # Load _base.yml first (if it exists)
    if [[ -f "$base_file" ]]; then
        _parse_workflow_yaml "$base_file"
    fi

    # Then merge scenario workflow
    _parse_workflow_yaml "$workflow_file"

    # Deduplicate arrays
    mapfile -t WORKFLOW_AGENTS < <(printf '%s\n' "${WORKFLOW_AGENTS[@]}" | sort -u)
    mapfile -t WORKFLOW_SKILL_CATEGORIES < <(printf '%s\n' "${WORKFLOW_SKILL_CATEGORIES[@]}" | sort -u)
    mapfile -t WORKFLOW_SKILL_INDIVIDUAL < <(printf '%s\n' "${WORKFLOW_SKILL_INDIVIDUAL[@]}" | sort -u)
    mapfile -t WORKFLOW_RULES < <(printf '%s\n' "${WORKFLOW_RULES[@]}" | sort -u)
}

print_usage() {
    local modules_list
    modules_list=$(IFS=,; echo "${ALL_MODULES[*]}")

    cat << EOF
Usage: $0 [OPTIONS]

Options:
  --global          Install to ~/.claude/ (all projects)
  --local           Install to ./.claude/ (current project only)
  --all             Install all modules
  --modules LIST    Install specific modules (comma-separated)
                    Available: $modules_list
  --with-skills     Include skills (on-demand knowledge)
  --with-mcp        Include MCP server configs
  --plugin NAME     Install a plugin bundle (see --list-plugins)
  --list-plugins    List available plugin bundles
  --workflow NAME   Install a scenario workflow (see --list-workflows)
  --list-workflows  List available scenario workflows
  -h, --help        Show this help

Examples:
  $0                        # Interactive mode
  $0 --global               # Global install, core only
  $0 --global --all         # Global install, all modules
  $0 --local --modules go,k8s --with-skills
  $0 --global --plugin k8s-ops --with-skills  # K8s operations bundle
  $0 --list-plugins                            # Show available bundles
  $0 --global --workflow compose-to-k8s        # Scenario workflow
  $0 --list-workflows                          # Show available workflows

EOF
}

# Parse arguments
INSTALL_SCOPE=""
INSTALL_ALL=false
SELECTED_MODULES=()
WITH_SKILLS=false
WITH_MCP=false
HAS_ARGS=false
PLUGIN_NAME=""
LIST_PLUGINS=false
WORKFLOW_NAME=""
LIST_WORKFLOWS=false

while [[ $# -gt 0 ]]; do
    HAS_ARGS=true
    case $1 in
        --global)
            INSTALL_SCOPE="global"
            shift
            ;;
        --local)
            INSTALL_SCOPE="local"
            shift
            ;;
        --all)
            INSTALL_ALL=true
            shift
            ;;
        --modules)
            if [[ -z "${2:-}" ]]; then
                log_error "Missing argument for --modules"
                exit 1
            fi
            IFS=',' read -ra SELECTED_MODULES <<< "$2"
            # Validate modules
            for mod in "${SELECTED_MODULES[@]}"; do
                if ! validate_module "$mod"; then
                    log_error "Invalid module: $mod"
                    log_error "Available modules: ${ALL_MODULES[*]}"
                    exit 1
                fi
            done
            shift 2
            ;;
        --with-skills)
            WITH_SKILLS=true
            shift
            ;;
        --with-mcp)
            WITH_MCP=true
            shift
            ;;
        --plugin)
            if [[ -z "${2:-}" ]]; then
                log_error "Missing argument for --plugin"
                exit 1
            fi
            PLUGIN_NAME="$2"
            shift 2
            ;;
        --list-plugins)
            LIST_PLUGINS=true
            shift
            ;;
        --workflow)
            if [[ -z "${2:-}" ]]; then
                log_error "Missing argument for --workflow"
                exit 1
            fi
            WORKFLOW_NAME="$2"
            shift 2
            ;;
        --list-workflows)
            LIST_WORKFLOWS=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

log_section "=== ress-claude-agents installer ==="
echo ""

# List plugins mode
if [[ "$LIST_PLUGINS" == true ]]; then
    log_section "Available plugin bundles:"
    echo ""
    for manifest in "$SCRIPT_DIR/plugins/"*.yml; do
        [[ -f "$manifest" ]] || continue
        pname=$(basename "$manifest" .yml)
        pdesc=$(grep '^description:' "$manifest" | sed 's/^description:[[:space:]]*//;s/^"//;s/"$//')
        echo "  $pname - $pdesc"
    done
    echo ""
    echo "Usage: $0 --global --plugin <name> [--with-skills]"
    exit 0
fi

# List workflows mode
if [[ "$LIST_WORKFLOWS" == true ]]; then
    log_section "Available scenario workflows:"
    echo ""
    for manifest in "$SCRIPT_DIR/.claude/workflows/"*.yml; do
        [[ -f "$manifest" ]] || continue
        wname=$(basename "$manifest" .yml)
        wdesc=$(grep '^description:' "$manifest" | sed 's/^description:[[:space:]]*//;s/^"//;s/"$//')
        if [[ "$wname" == "_base" ]]; then
            echo "  $wname (auto-included) - $wdesc"
        else
            echo "  $wname - $wdesc"
        fi
    done
    echo ""
    echo "Usage: $0 --global --workflow <name>"
    exit 0
fi

# Interactive mode if no scope specified
if [[ -z "$INSTALL_SCOPE" ]]; then
    log_warn "Select installation scope:"
    echo "  1) Global (~/.claude/) - applies to all projects"
    echo "  2) Local  (./.claude/) - applies to current project only"
    read -rp "Choice [1/2]: " scope_choice
    case $scope_choice in
        1) INSTALL_SCOPE="global" ;;
        2) INSTALL_SCOPE="local" ;;
        *) log_error "Invalid choice"; exit 1 ;;
    esac
    echo ""
fi

# Set target directory
if [[ "$INSTALL_SCOPE" == "global" ]]; then
    TARGET_DIR="$HOME/.claude"
    log_info "Installing globally to: $TARGET_DIR"
else
    TARGET_DIR="$(pwd)/.claude"
    log_info "Installing locally to: $TARGET_DIR"
fi

# Interactive module selection if not specified (skip if plugin or workflow mode)
if [[ "$INSTALL_ALL" == false && ${#SELECTED_MODULES[@]} -eq 0 && -z "$PLUGIN_NAME" && -z "$WORKFLOW_NAME" ]]; then
    echo ""
    log_warn "Select modules to install:"
    echo "  0) Core only (CLAUDE.md + session)"
    echo "  1) All modules"
    echo "  2) Select individually"
    read -rp "Choice [0/1/2]: " module_choice

    case $module_choice in
        0)
            SELECTED_MODULES=()
            ;;
        1)
            INSTALL_ALL=true
            ;;
        2)
            echo ""
            for mod in "${ALL_MODULES[@]}"; do
                read -rp "  Include $mod? [y/N]: " -n 1 reply
                echo ""
                if [[ "$reply" =~ ^[Yy]$ ]]; then
                    SELECTED_MODULES+=("$mod")
                fi
            done
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
    echo ""
fi

# Skills selection (interactive)
if [[ "$WITH_SKILLS" == false && "$HAS_ARGS" == false ]]; then
    read -rp "Include skills (on-demand knowledge)? [y/N]: " -n 1 reply
    echo ""
    if [[ "$reply" =~ ^[Yy]$ ]]; then
        WITH_SKILLS=true
    fi
fi

# MCP selection (interactive, only for global)
if [[ "$INSTALL_SCOPE" == "global" && "$WITH_MCP" == false && "$HAS_ARGS" == false ]]; then
    read -rp "Include MCP server configs? [y/N]: " -n 1 reply
    echo ""
    if [[ "$reply" =~ ^[Yy]$ ]]; then
        WITH_MCP=true
    fi
fi

# Set modules to install
if [[ "$INSTALL_ALL" == true ]]; then
    SELECTED_MODULES=("${ALL_MODULES[@]}")
fi

# Always include session in commands
SELECTED_MODULES+=("session")

echo ""
log_section "=== Installing ==="
echo ""

# Create target directories
create_dir "$TARGET_DIR"
create_dir "$TARGET_DIR/commands"

# Install core CLAUDE.md
log_info "[core] Installing CLAUDE.md..."
if backup_and_link "$SCRIPT_DIR/global/CLAUDE.md" "$TARGET_DIR/CLAUDE.md" "$INSTALL_SCOPE" "file"; then
    INSTALLED_COMPONENTS+=("Core (CLAUDE.md)")
    if [[ "$INSTALL_SCOPE" == "local" ]]; then
        log_warn "  (Edit this file to customize for your project)"
    fi
else
    log_error "Failed to install CLAUDE.md"
    INSTALL_SUCCESS=false
fi

# Install selected command modules
for mod in "${SELECTED_MODULES[@]}"; do
    source_dir="$SCRIPT_DIR/commands/$mod"
    if [[ -d "$source_dir" ]]; then
        log_info "[$mod] Installing commands..."
        target="$TARGET_DIR/commands/$mod"

        if backup_and_link "$source_dir" "$target" "$INSTALL_SCOPE" "dir"; then
            if [[ "$mod" != "session" ]]; then
                INSTALLED_COMPONENTS+=("$mod commands")
            fi
        else
            log_error "Failed to install $mod commands"
            INSTALL_SUCCESS=false
        fi
    else
        log_warn "[$mod] Module directory not found, skipping"
    fi
done

# Install plugin agents
if [[ -n "$PLUGIN_NAME" ]]; then
    resolve_plugin "$PLUGIN_NAME"

    log_info "[plugin:$PLUGIN_NAME] Installing agents..."
    AGENTS_SOURCE="$SCRIPT_DIR/.claude/agents"
    AGENTS_TARGET="$TARGET_DIR/agents"
    create_dir "$AGENTS_TARGET"

    for agent in "${PLUGIN_AGENTS[@]}"; do
        agent_file="$AGENTS_SOURCE/${agent}.md"
        if [[ -f "$agent_file" ]]; then
            if backup_and_link "$agent_file" "$AGENTS_TARGET/${agent}.md" "$INSTALL_SCOPE" "file"; then
                echo "    + Agent: $agent"
            fi
        else
            log_warn "    Agent not found: $agent"
        fi
    done
    INSTALLED_COMPONENTS+=("Plugin: $PLUGIN_NAME (${#PLUGIN_AGENTS[@]} agents)")

    # Install plugin skill categories
    if [[ "$WITH_SKILLS" == true && ${#PLUGIN_SKILL_CATEGORIES[@]} -gt 0 ]]; then
        log_info "[plugin:$PLUGIN_NAME] Installing skill categories..."
        SKILLS_SOURCE="$SCRIPT_DIR/.claude/skills"
        SKILLS_TARGET="$TARGET_DIR/skills"
        create_dir "$SKILLS_TARGET"

        for category in "${PLUGIN_SKILL_CATEGORIES[@]}"; do
            cat_dir="$SKILLS_SOURCE/$category"
            if [[ -d "$cat_dir" ]]; then
                create_dir "$SKILLS_TARGET/$category"
                for skill_file in "$cat_dir"/*.md; do
                    [[ -f "$skill_file" ]] || continue
                    skill_name=$(basename "$skill_file")
                    if backup_and_link "$skill_file" "$SKILLS_TARGET/$category/$skill_name" "$INSTALL_SCOPE" "file"; then
                        echo "    + Skill: $category/$skill_name"
                    fi
                    # Also flatten to root for backward compat
                    if [[ ! -e "$SKILLS_TARGET/$skill_name" ]]; then
                        ln -sf "$skill_file" "$SKILLS_TARGET/$skill_name" 2>/dev/null || true
                    fi
                done
            else
                log_warn "    Skill category not found: $category"
            fi
        done
        INSTALLED_COMPONENTS+=("Plugin skills: ${PLUGIN_SKILL_CATEGORIES[*]}")
    fi
fi

# Install workflow
if [[ -n "$WORKFLOW_NAME" ]]; then
    resolve_workflow "$WORKFLOW_NAME"

    # Install workflow agents
    if [[ ${#WORKFLOW_AGENTS[@]} -gt 0 ]]; then
        log_info "[workflow:$WORKFLOW_NAME] Installing agents..."
        AGENTS_SOURCE="$SCRIPT_DIR/.claude/agents"
        AGENTS_TARGET="$TARGET_DIR/agents"
        create_dir "$AGENTS_TARGET"

        for agent in "${WORKFLOW_AGENTS[@]}"; do
            agent_file="$AGENTS_SOURCE/${agent}.md"
            if [[ -f "$agent_file" ]]; then
                if backup_and_link "$agent_file" "$AGENTS_TARGET/${agent}.md" "$INSTALL_SCOPE" "file"; then
                    echo "    + Agent: $agent"
                fi
            else
                log_warn "    Agent not found: $agent"
            fi
        done
        INSTALLED_COMPONENTS+=("Workflow: $WORKFLOW_NAME (${#WORKFLOW_AGENTS[@]} agents)")
    fi

    # Install workflow rules
    if [[ ${#WORKFLOW_RULES[@]} -gt 0 ]]; then
        log_info "[workflow:$WORKFLOW_NAME] Installing rules..."
        RULES_SOURCE="$SCRIPT_DIR/.claude/rules"
        RULES_TARGET="$TARGET_DIR/rules"
        create_dir "$RULES_TARGET"

        for rule in "${WORKFLOW_RULES[@]}"; do
            rule_file="$RULES_SOURCE/${rule}.md"
            if [[ -f "$rule_file" ]]; then
                if backup_and_link "$rule_file" "$RULES_TARGET/${rule}.md" "$INSTALL_SCOPE" "file"; then
                    echo "    + Rule: $rule"
                fi
            else
                log_warn "    Rule not found: $rule"
            fi
        done
        INSTALLED_COMPONENTS+=("Workflow rules: ${WORKFLOW_RULES[*]}")
    fi

    # Install workflow skill categories
    if [[ ${#WORKFLOW_SKILL_CATEGORIES[@]} -gt 0 ]]; then
        log_info "[workflow:$WORKFLOW_NAME] Installing skill categories..."
        SKILLS_SOURCE="$SCRIPT_DIR/.claude/skills"
        SKILLS_TARGET="$TARGET_DIR/skills"
        create_dir "$SKILLS_TARGET"

        for category in "${WORKFLOW_SKILL_CATEGORIES[@]}"; do
            cat_dir="$SKILLS_SOURCE/$category"
            if [[ -d "$cat_dir" ]]; then
                create_dir "$SKILLS_TARGET/$category"
                for skill_file in "$cat_dir"/*.md; do
                    [[ -f "$skill_file" ]] || continue
                    skill_name=$(basename "$skill_file")
                    if backup_and_link "$skill_file" "$SKILLS_TARGET/$category/$skill_name" "$INSTALL_SCOPE" "file"; then
                        echo "    + Skill: $category/$skill_name"
                    fi
                    if [[ ! -e "$SKILLS_TARGET/$skill_name" ]]; then
                        ln -sf "$skill_file" "$SKILLS_TARGET/$skill_name" 2>/dev/null || true
                    fi
                done
            else
                log_warn "    Skill category not found: $category"
            fi
        done
    fi

    # Install workflow individual skills
    if [[ ${#WORKFLOW_SKILL_INDIVIDUAL[@]} -gt 0 ]]; then
        log_info "[workflow:$WORKFLOW_NAME] Installing individual skills..."
        SKILLS_SOURCE="$SCRIPT_DIR/.claude/skills"
        SKILLS_TARGET="$TARGET_DIR/skills"
        create_dir "$SKILLS_TARGET"

        for skill_path in "${WORKFLOW_SKILL_INDIVIDUAL[@]}"; do
            # skill_path format: category/skill-name (e.g., dx/spec-driven-development)
            skill_dir=$(dirname "$skill_path")
            skill_base=$(basename "$skill_path")
            source_file="$SKILLS_SOURCE/${skill_path}.md"

            if [[ -f "$source_file" ]]; then
                create_dir "$SKILLS_TARGET/$skill_dir"
                if backup_and_link "$source_file" "$SKILLS_TARGET/${skill_path}.md" "$INSTALL_SCOPE" "file"; then
                    echo "    + Skill: ${skill_path}"
                fi
                if [[ ! -e "$SKILLS_TARGET/${skill_base}.md" ]]; then
                    ln -sf "$source_file" "$SKILLS_TARGET/${skill_base}.md" 2>/dev/null || true
                fi
            else
                log_warn "    Skill not found: $skill_path"
            fi
        done
        INSTALLED_COMPONENTS+=("Workflow skills: ${#WORKFLOW_SKILL_CATEGORIES[@]} categories, ${#WORKFLOW_SKILL_INDIVIDUAL[@]} individual")
    fi
fi

# Install skills
if [[ "$WITH_SKILLS" == true ]]; then
    log_info "[skills] Installing skills..."
    SKILLS_SOURCE="$SCRIPT_DIR/.claude/skills"
    SKILLS_TARGET="$TARGET_DIR/skills"

    if [[ -d "$SKILLS_SOURCE" ]]; then
        if backup_and_link "$SKILLS_SOURCE" "$SKILLS_TARGET" "$INSTALL_SCOPE" "dir"; then
            INSTALLED_COMPONENTS+=("Skills")
            # Flatten: 서브디렉토리 내 파일들을 root에 심볼릭 링크
            while IFS= read -r skill_file; do
                skill_name=$(basename "$skill_file")
                if [[ ! -e "$SKILLS_TARGET/$skill_name" ]]; then
                    ln -sf "$skill_file" "$SKILLS_TARGET/$skill_name"
                fi
            done < <(find "$SKILLS_SOURCE" -mindepth 2 -name "*.md" -type f)
        else
            log_error "Failed to install skills"
            INSTALL_SUCCESS=false
        fi
    else
        log_warn "  (skills directory not found, skipping)"
    fi
fi

# Install MCP configs (global only)
if [[ "$WITH_MCP" == true && "$INSTALL_SCOPE" == "global" ]]; then
    log_info "[mcp] Installing MCP configs..."
    MCP_SOURCE="$SCRIPT_DIR/mcp-configs/settings.json"
    MCP_TARGET="$TARGET_DIR/settings.json"

    if backup_and_link "$MCP_SOURCE" "$MCP_TARGET" "local" "file"; then
        INSTALLED_COMPONENTS+=("MCP configs")
    else
        log_error "Failed to install MCP configs"
        INSTALL_SUCCESS=false
    fi
fi

# Summary
echo ""
if [[ "$INSTALL_SUCCESS" == true ]]; then
    log_section "=== Installation complete! ==="
else
    log_section "=== Installation completed with errors ==="
fi
echo ""
echo "Installed to: $TARGET_DIR"
echo ""

echo "Components:"
for component in "${INSTALLED_COMPONENTS[@]}"; do
    echo "  + $component"
done

if [[ ${#BACKUP_FILES[@]} -gt 0 ]]; then
    echo ""
    echo "Backup files created:"
    for backup in "${BACKUP_FILES[@]}"; do
        echo "  - $backup"
    done
fi

echo ""
if [[ "$INSTALL_SCOPE" == "local" ]]; then
    log_warn "Note: Add .claude/ to .gitignore if needed"
    echo ""
fi

echo "Available commands:"
echo "  /session save  - Save session context"
echo "  /session end   - End session and cleanup"
for mod in "${SELECTED_MODULES[@]}"; do
    case $mod in
        backend)
            echo "  /backend review, /backend test-gen, /backend api-doc, /backend refactor"
            ;;
        go)
            echo "  /go review, /go test-gen, /go lint, /go refactor"
            ;;
        k8s)
            echo "  /k8s validate, /k8s secure, /k8s netpol, /k8s helm-check"
            ;;
        terraform)
            echo "  /terraform plan-review, /terraform security, /terraform module-gen, /terraform validate"
            ;;
        dx)
            echo "  /dx pr-create, /dx issue-create, /dx changelog, /dx release"
            ;;
    esac
done
echo ""

# Exit with appropriate status
if [[ "$INSTALL_SUCCESS" == true ]]; then
    exit 0
else
    exit 1
fi
