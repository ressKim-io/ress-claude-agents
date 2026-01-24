# ress-claude-agents

Personal Claude Code agents and configs for DevOps & backend development.

## Structure

```
ress-claude-agents/
├── .claude/
│   └── skills/                    # On-demand domain knowledge
│       ├── go-errors.md           # Go error handling patterns
│       ├── go-gin.md              # Gin framework patterns
│       ├── go-testing.md          # Go testing patterns
│       ├── k8s-security.md        # K8s security patterns
│       ├── k8s-helm.md            # Helm best practices
│       ├── terraform-modules.md   # Terraform module patterns
│       ├── terraform-security.md  # Terraform security
│       └── git-workflow.md        # Git conventions
├── global/
│   └── CLAUDE.md                  # Global settings (50 lines)
├── commands/
│   ├── backend/                   # Java/Kotlin commands
│   ├── go/                        # Go commands
│   ├── k8s/                       # Kubernetes commands
│   ├── terraform/                 # Terraform commands
│   └── dx/                        # DX commands
├── project-templates/
│   ├── backend-go/CLAUDE.md       # Go backend (~60 lines)
│   ├── backend-java/CLAUDE.md     # Java backend (~60 lines)
│   ├── k8s/CLAUDE.md              # Kubernetes (~60 lines)
│   └── terraform/CLAUDE.md        # Terraform (~60 lines)
└── mcp-configs/
    └── settings.json              # MCP server settings
```

## Features

### Compact CLAUDE.md Files
- **Before**: 380+ lines average
- **After**: 50-80 lines (Quick Reference, CRITICAL Rules, Common Mistakes)

### Skills (On-demand Loading)
Domain-specific knowledge loaded only when needed via `/skill-name`.

### Command Contracts
Every command includes a Contract table:
| Aspect | Description |
|--------|-------------|
| Input | What this operates on |
| Output | What this produces |
| Required Tools | Dependencies |
| Verification | Success check |

## Installation

```bash
./install.sh
```

This creates symlinks:
- `~/.claude/CLAUDE.md` → global/CLAUDE.md
- `~/.claude/commands/` → commands/
- `~/.claude/skills/` → .claude/skills/

## Usage

### Project Templates
Copy to your project root:

```bash
# Go backend
cp project-templates/backend-go/CLAUDE.md /your/project/

# Kubernetes
cp project-templates/k8s/CLAUDE.md /your/project/

# Terraform
cp project-templates/terraform/CLAUDE.md /your/project/
```

### Commands (20 total)

| Category | Commands |
|----------|----------|
| Go | `/review`, `/test-gen`, `/lint`, `/refactor` |
| Backend | `/review`, `/test-gen`, `/api-doc`, `/refactor` |
| K8s | `/validate`, `/secure`, `/netpol`, `/helm-check` |
| Terraform | `/plan-review`, `/security`, `/module-gen`, `/validate` |
| DX | `/pr-create`, `/issue-create`, `/changelog`, `/release` |

### Skills (8 total)

```
/go-errors         Go error handling
/go-gin            Gin framework
/go-testing        Go testing
/k8s-security      Kubernetes security
/k8s-helm          Helm best practices
/terraform-modules Terraform modules
/terraform-security Terraform security
/git-workflow      Git conventions
```

## Design Principles

1. **Concise CLAUDE.md**: Only essential rules that prevent mistakes
2. **On-demand Skills**: Detailed patterns loaded when needed
3. **Command Contracts**: Clear input/output/verification
4. **Common Mistakes Table**: Quick reference for anti-patterns
5. **Verification Commands**: Every rule has a check command

## Reference

- [Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- Key principle: "For each line, ask: 'Would removing this cause Claude to make mistakes?'"
