# Global Claude Code Settings

## Language
- Response: 한국어
- Code comments: English
- Commit messages: English

## CRITICAL Rules

1. **No Secrets in Code** - Verify: `grep -r "password\|secret\|api_key" .`
   - Use environment variables or secret managers
   - Never commit .env files

2. **PR Size Limit** - Max 400 lines changed
   - Split large features into multiple PRs

3. **Test Coverage** - Minimum 80%
   - All new features must include tests

## Git Conventions

### Commit Format
```
<type>(<scope>): <subject>
```
Types: feat, fix, docs, style, refactor, test, chore

### Branch Naming
```
feature/#123-description
fix/#456-description
```

## Common Mistakes

| Mistake | Correct | Why |
|---------|---------|-----|
| `git add .` blindly | Review changes first | Avoid secrets |
| Large PRs (1000+ lines) | Split into smaller PRs | Review quality |
| No issue reference | Link to issue | Traceability |
| Vague commit messages | Descriptive messages | History clarity |

## Skills Reference
- `/git-workflow` - Git conventions and patterns

## DX Commands
- `/pr-create` - Create PR from commits
- `/issue-create` - Create GitHub Issue
- `/changelog` - Generate CHANGELOG
- `/release` - Create release with tag

---
*Project-specific settings in project CLAUDE.md*
