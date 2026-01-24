#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Available modules
ALL_MODULES=("backend" "go" "k8s" "terraform" "dx")

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --global          Install to ~/.claude/ (all projects)"
    echo "  --local           Install to ./.claude/ (current project only)"
    echo "  --all             Install all modules"
    echo "  --modules LIST    Install specific modules (comma-separated)"
    echo "                    Available: backend, go, k8s, terraform, dx"
    echo "  --with-skills     Include skills (on-demand knowledge)"
    echo "  --with-mcp        Include MCP server configs"
    echo "  -h, --help        Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                        # Interactive mode"
    echo "  $0 --global               # Global install, core only"
    echo "  $0 --global --all         # Global install, all modules"
    echo "  $0 --local --modules go,k8s --with-skills"
    echo ""
}

# Parse arguments
INSTALL_SCOPE=""
INSTALL_ALL=false
SELECTED_MODULES=()
WITH_SKILLS=false
WITH_MCP=false

while [[ $# -gt 0 ]]; do
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
            IFS=',' read -ra SELECTED_MODULES <<< "$2"
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
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            print_usage
            exit 1
            ;;
    esac
done

echo -e "${BLUE}=== ress-claude-agents installer ===${NC}"
echo ""

# Interactive mode if no scope specified
if [ -z "$INSTALL_SCOPE" ]; then
    echo -e "${YELLOW}Select installation scope:${NC}"
    echo "  1) Global (~/.claude/) - applies to all projects"
    echo "  2) Local  (./.claude/) - applies to current project only"
    read -p "Choice [1/2]: " scope_choice
    case $scope_choice in
        1) INSTALL_SCOPE="global" ;;
        2) INSTALL_SCOPE="local" ;;
        *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
    esac
    echo ""
fi

# Set target directory
if [ "$INSTALL_SCOPE" = "global" ]; then
    TARGET_DIR="$HOME/.claude"
    echo -e "${GREEN}Installing globally to: $TARGET_DIR${NC}"
else
    TARGET_DIR="$(pwd)/.claude"
    echo -e "${GREEN}Installing locally to: $TARGET_DIR${NC}"
fi

# Interactive module selection if not specified
if [ "$INSTALL_ALL" = false ] && [ ${#SELECTED_MODULES[@]} -eq 0 ]; then
    echo ""
    echo -e "${YELLOW}Select modules to install:${NC}"
    echo "  0) Core only (CLAUDE.md + session)"
    echo "  1) All modules"
    echo "  2) Select individually"
    read -p "Choice [0/1/2]: " module_choice

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
                read -p "  Include $mod? [y/N]: " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    SELECTED_MODULES+=("$mod")
                fi
            done
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
    echo ""
fi

# Skills selection (interactive)
if [ "$WITH_SKILLS" = false ] && [ -z "$1" ]; then
    read -p "Include skills (on-demand knowledge)? [y/N]: " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        WITH_SKILLS=true
    fi
fi

# MCP selection (interactive, only for global)
if [ "$INSTALL_SCOPE" = "global" ] && [ "$WITH_MCP" = false ] && [ -z "$1" ]; then
    read -p "Include MCP server configs? [y/N]: " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        WITH_MCP=true
    fi
fi

# Set modules to install
if [ "$INSTALL_ALL" = true ]; then
    SELECTED_MODULES=("${ALL_MODULES[@]}")
fi

# Always include session in commands
SELECTED_MODULES+=("session")

echo ""
echo -e "${BLUE}=== Installing ===${NC}"
echo ""

# Create target directory
mkdir -p "$TARGET_DIR"
mkdir -p "$TARGET_DIR/commands"

# Install core CLAUDE.md
echo -e "${GREEN}[core]${NC} Installing CLAUDE.md..."
if [ -L "$TARGET_DIR/CLAUDE.md" ]; then
    rm "$TARGET_DIR/CLAUDE.md"
elif [ -f "$TARGET_DIR/CLAUDE.md" ]; then
    echo "  Backing up existing CLAUDE.md"
    mv "$TARGET_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md.backup"
fi

if [ "$INSTALL_SCOPE" = "global" ]; then
    ln -s "$SCRIPT_DIR/global/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
    echo "  -> Linked: $TARGET_DIR/CLAUDE.md"
else
    cp "$SCRIPT_DIR/global/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
    echo "  -> Copied: $TARGET_DIR/CLAUDE.md"
    echo -e "  ${YELLOW}(Edit this file to customize for your project)${NC}"
fi

# Install selected command modules
for mod in "${SELECTED_MODULES[@]}"; do
    if [ -d "$SCRIPT_DIR/commands/$mod" ]; then
        echo -e "${GREEN}[$mod]${NC} Installing commands..."
        target="$TARGET_DIR/commands/$mod"

        if [ -L "$target" ]; then
            rm "$target"
        elif [ -d "$target" ]; then
            mv "$target" "$target.backup"
        fi

        if [ "$INSTALL_SCOPE" = "global" ]; then
            ln -s "$SCRIPT_DIR/commands/$mod" "$target"
            echo "  -> Linked: $target"
        else
            cp -r "$SCRIPT_DIR/commands/$mod" "$target"
            echo "  -> Copied: $target"
        fi
    fi
done

# Install skills
if [ "$WITH_SKILLS" = true ]; then
    echo -e "${GREEN}[skills]${NC} Installing skills..."
    SKILLS_SOURCE="$SCRIPT_DIR/.claude/skills"
    SKILLS_TARGET="$TARGET_DIR/skills"

    if [ -d "$SKILLS_SOURCE" ]; then
        if [ -L "$SKILLS_TARGET" ]; then
            rm "$SKILLS_TARGET"
        elif [ -d "$SKILLS_TARGET" ]; then
            mv "$SKILLS_TARGET" "$SKILLS_TARGET.backup"
        fi

        if [ "$INSTALL_SCOPE" = "global" ]; then
            ln -s "$SKILLS_SOURCE" "$SKILLS_TARGET"
            echo "  -> Linked: $SKILLS_TARGET"
        else
            cp -r "$SKILLS_SOURCE" "$SKILLS_TARGET"
            echo "  -> Copied: $SKILLS_TARGET"
        fi
    else
        echo -e "  ${YELLOW}(skills directory not found, skipping)${NC}"
    fi
fi

# Install MCP configs (global only)
if [ "$WITH_MCP" = true ] && [ "$INSTALL_SCOPE" = "global" ]; then
    echo -e "${GREEN}[mcp]${NC} Installing MCP configs..."
    MCP_SETTINGS="$TARGET_DIR/settings.json"
    if [ -f "$MCP_SETTINGS" ]; then
        cp "$MCP_SETTINGS" "$MCP_SETTINGS.backup"
        echo "  Backed up existing settings.json"
    fi
    cp "$SCRIPT_DIR/mcp-configs/settings.json" "$MCP_SETTINGS"
    echo "  -> Copied: $MCP_SETTINGS"
fi

# Summary
echo ""
echo -e "${BLUE}=== Installation complete! ===${NC}"
echo ""
echo "Installed to: $TARGET_DIR"
echo ""
echo "Components:"
echo "  ✓ Core (CLAUDE.md + session context)"
for mod in "${SELECTED_MODULES[@]}"; do
    if [ "$mod" != "session" ]; then
        echo "  ✓ $mod commands"
    fi
done
if [ "$WITH_SKILLS" = true ]; then
    echo "  ✓ Skills (on-demand knowledge)"
fi
if [ "$WITH_MCP" = true ]; then
    echo "  ✓ MCP configs"
fi

echo ""
if [ "$INSTALL_SCOPE" = "local" ]; then
    echo -e "${YELLOW}Note: Add .claude/ to .gitignore if needed${NC}"
    echo ""
fi

echo "Available commands:"
echo "  /session save  - Save session context"
echo "  /session end   - End session and cleanup"
for mod in "${SELECTED_MODULES[@]}"; do
    case $mod in
        backend) echo "  /backend review, /backend test-gen, /backend api-doc, /backend refactor" ;;
        go) echo "  /go review, /go test-gen, /go lint, /go refactor" ;;
        k8s) echo "  /k8s validate, /k8s secure, /k8s netpol, /k8s helm-check" ;;
        terraform) echo "  /terraform plan-review, /terraform security, /terraform module-gen, /terraform validate" ;;
        dx) echo "  /dx pr-create, /dx issue-create, /dx changelog, /dx release" ;;
    esac
done
echo ""
