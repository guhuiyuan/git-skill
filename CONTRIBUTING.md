# Contributing

Thank you for considering a contribution to Git Skill! :tada:

## Code of Conduct

Be respectful. We're all here to learn and build.

## How to Contribute

1. **Fork** the repository
2. **Create a branch** (`git checkout -b feature/my-improvement`)
3. **Make your changes**
4. **Test** on at least one platform (Windows / macOS / Linux)
5. **Commit** with conventional commit messages (`feat:` / `fix:` / `docs:` / `refactor:` / `test:`)
6. **Push** and open a Pull Request

## Development Setup

```bash
git clone https://github.com/<owner>/git-skill.git
cd git-skill
# Test install in a sandboxed location
SKILL_HOME="$HOME/.claude/skills/git-test" ./install.sh
```

## Adding a New Secret Pattern

If you'd like to add a new pattern to the embedded rules:

1. Open `skills/git/scripts/check-secrets.sh` and `.ps1`
2. Add the pattern with severity classification (CRITICAL / HIGH / LOW)
3. Add a test case in `skills/git/scripts/_lib/test-secrets.sh`
4. Update `skills/git/references/secret-patterns.md` with rationale and example
5. Cite the source (gitleaks rule ID, public CVE, etc.)

## Adding a New .gitignore Template

1. Create file in `skills/git/templates/gitignore/<lang>.gitignore`
2. Update the detection logic in `skills/git/scripts/generate-gitignore.sh`
3. Update `skills/git/references/gitignore-templates.md`

## Adding a New Platform Adapter

1. Create `skills/git/scripts/_platform/<platform>.sh` (CLI wrapper)
2. Create `skills/git/scripts/_platform/<platform>-api.sh` (REST fallback)
3. Update `platform-detect.sh` to recognize the new platform
4. Update `references/auth-guide.md` with token scopes

## Style Guide

### Shell Scripts

- `#!/usr/bin/env bash`
- `set -euo pipefail`
- `IFS=$'\n\t'`
- Functions: `snake_case`
- Variables: `UPPER_CASE` for globals, `lower_case` for locals
- Indent: 2 spaces
- Use `${VAR}` instead of `$VAR` in mixed-context strings
- Use `[[ ]]` instead of `[ ]`
- Use `command -v` instead of `which`
- Use `mktemp` for temp files
- Always quote variables: `"${var}"`

### PowerShell Scripts

- Use approved verbs (Get-, Set-, New-, Remove-, etc.)
- PascalCase for functions, camelCase for variables
- `$ErrorActionPreference = 'Stop'`
- Use `Join-Path` instead of string concatenation
- Use `Test-Path` before operations

## Testing

Before submitting:

```bash
# Run shellcheck
shellcheck skills/git/scripts/**/*.sh

# Run a smoke test
bash skills/git/scripts/_lib/test-smoke.sh
```

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add giteao webhook support
fix: gitleaks fallback when binary missing
docs: update auth-guide.md with Gitee scopes
refactor: extract _platform common functions
test: add CRITICAL secret pattern test cases
```

## License

By contributing, you agree that your contributions will be licensed under MIT.