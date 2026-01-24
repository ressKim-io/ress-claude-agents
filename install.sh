#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "=== ress-claude-agents installer ==="
echo ""

# Create ~/.claude directory if not exists
if [ ! -d "$CLAUDE_DIR" ]; then
    echo "Creating $CLAUDE_DIR..."
    mkdir -p "$CLAUDE_DIR"
fi

# Symlink global CLAUDE.md
echo "Setting up global CLAUDE.md..."
if [ -L "$CLAUDE_DIR/CLAUDE.md" ]; then
    rm "$CLAUDE_DIR/CLAUDE.md"
elif [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    echo "  Backing up existing CLAUDE.md to CLAUDE.md.backup"
    mv "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.backup"
fi
ln -s "$SCRIPT_DIR/global/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
echo "  -> Linked: $CLAUDE_DIR/CLAUDE.md"

# Symlink commands directory
echo "Setting up commands..."
if [ ! -d "$CLAUDE_DIR/commands" ]; then
    mkdir -p "$CLAUDE_DIR/commands"
fi

for cmd_dir in "$SCRIPT_DIR/commands"/*; do
    if [ -d "$cmd_dir" ]; then
        cmd_name=$(basename "$cmd_dir")
        target="$CLAUDE_DIR/commands/$cmd_name"

        if [ -L "$target" ]; then
            rm "$target"
        elif [ -d "$target" ]; then
            echo "  Backing up existing $cmd_name to $cmd_name.backup"
            mv "$target" "$target.backup"
        fi

        ln -s "$cmd_dir" "$target"
        echo "  -> Linked: $target"
    fi
done

# Symlink skills directory
echo "Setting up skills..."
SKILLS_SOURCE="$SCRIPT_DIR/.claude/skills"
SKILLS_TARGET="$CLAUDE_DIR/skills"

if [ -d "$SKILLS_SOURCE" ]; then
    if [ -L "$SKILLS_TARGET" ]; then
        rm "$SKILLS_TARGET"
    elif [ -d "$SKILLS_TARGET" ]; then
        echo "  Backing up existing skills to skills.backup"
        mv "$SKILLS_TARGET" "$SKILLS_TARGET.backup"
    fi

    ln -s "$SKILLS_SOURCE" "$SKILLS_TARGET"
    echo "  -> Linked: $SKILLS_TARGET"
else
    echo "  (no skills directory found, skipping)"
fi

# Symlink MCP configs (optional - user can choose)
echo ""
read -p "Do you want to install MCP configs? [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    MCP_SETTINGS="$CLAUDE_DIR/settings.json"
    if [ -f "$MCP_SETTINGS" ]; then
        echo "  Backing up existing settings.json to settings.json.backup"
        cp "$MCP_SETTINGS" "$MCP_SETTINGS.backup"
    fi
    cp "$SCRIPT_DIR/mcp-configs/settings.json" "$MCP_SETTINGS"
    echo "  -> Copied: $MCP_SETTINGS"
fi

echo ""
echo "=== Installation complete! ==="
echo ""
echo "Installed components:"
echo "  - Global CLAUDE.md: $CLAUDE_DIR/CLAUDE.md"
echo "  - Commands: $CLAUDE_DIR/commands/"
echo "  - Skills: $CLAUDE_DIR/skills/"
echo ""
echo "To use project templates, copy them manually:"
echo "  cp $SCRIPT_DIR/project-templates/<type>/CLAUDE.md /your/project/"
