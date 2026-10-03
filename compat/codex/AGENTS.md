# AGENTS.md — Codex CLI rules for git-skill

> Codex CLI 入口。所有脚本与详细文档都在 `skills/git/`(Claude Code / Cursor 共享)。

## Quick Start

```bash
# Deploy scripts to user-local location
cp -r skills/git ~/.local/share/git-skill

# Symlink this AGENTS.md into project root or ~/.codex/
ln -sf "$(pwd)/compat/codex/AGENTS.md" ~/.codex/AGENTS.md
# Or per-project:
ln -sf "$(pwd)/compat/codex/AGENTS.md" ./AGENTS.md
```

## When to Activate

Activate when user mentions any of:

- git, commit, push, pull, branch, merge, rebase, tag, stash
- GitHub, Gitee, pull request, PR, issue
- upload to GitHub, push to Gitee, clone repository
- sensitive files, secrets, tokens, .env, private keys
- "把项目上传到 GitHub", "推到 Gitee", "提交代码", "新建分支", "扫描密钥"

## Available Commands

All commands live at `~/.local/share/git-skill/scripts/` (or `${GIT_SKILL_HOME}`):

```bash
# Core flows (use these instead of raw git)
GIT_SKILL_HOME=~/.local/share/git-skill

$GIT_SKILL_HOME/scripts/git-init-flow.sh              # init + .gitignore + first commit
$GIT_SKILL_HOME/scripts/git-commit-flow.sh -m "msg"   # commit with secret scan
$GIT_SKILL_HOME/scripts/git-push-flow.sh              # push (re-scans secrets)
$GIT_SKILL_HOME/scripts/git-branch-flow.sh new <name> # branch management
$GIT_SKILL_HOME/scripts/git-merge-flow.sh <branch>    # merge with pre-scan
$GIT_SKILL_HOME/scripts/git-clone-flow.sh <url>       # clone + auto-detect platform
$GIT_SKILL_HOME/scripts/git-issue-flow.sh list        # list issues
$GIT_SKILL_HOME/scripts/git-pr-flow.sh new -m "..."   # create PR

# Standalone utilities
$GIT_SKILL_HOME/scripts/check-secrets.sh --staged --severity critical,high
$GIT_SKILL_HOME/scripts/generate-gitignore.sh --auto
$GIT_SKILL_HOME/scripts/generate-readme.sh --style standard
$GIT_SKILL_HOME/scripts/generate-license.sh --type MIT
$GIT_SKILL_HOME/scripts/auth-detect.sh --guide        # auth setup wizard
```

## Platform Routing

Auto-detect from `git remote get-url origin`:

| Remote URL contains | Platform | Adapter |
|---|---|---|
| `github.com` | github | `gh` CLI / `GH_TOKEN` REST / SSH |
| `gitee.com` | gitee | `gitee` CLI / `GITEE_TOKEN` REST / SSH |
| Other | unknown | manual only |

See `skills/git/references/platform-gitee.md` for Gitee API quirks.

## Security Policy (Three-Tier)

| Tier | Default | Override |
|---|---|---|
| CRITICAL (real keys) | Block | **Cannot bypass** |
| HIGH | Block | `--force-allow-high` |
| LOW | Warn | Always allowed |

The `check-secrets.sh` script enforces this. Always invoke it before `git commit` / `git push`.

## Working Directory

- Always treat current working directory as the project root
- **NEVER `cd` into other directories** (security boundary)
- Outside a git repo, only `init` / `clone` are allowed
- Destructive operations (`reset --hard`, `branch -D`, `push --force`, `stash drop`) require explicit user confirmation

## Installation Verification

```bash
ls ~/.local/share/git-skill/scripts/check-secrets.sh
gitleaks version   # recommended (skill uses it if available)
gh --version       # optional (GitHub CLI)
```

## Detailed Reference

For anything beyond 1 paragraph, **Read** the relevant file:

- `skills/git/references/workflows.md` — 6 typical scenarios (A-F)
- `skills/git/references/command-reference.md` — full verb list
- `skills/git/references/auth-guide.md` — auth + OS keychain
- `skills/git/references/secret-patterns.md` — embedded rules
- `skills/git/references/troubleshooting.md` — error fixes
- `skills/git/references/proactive-suggestions.md` — proactive advisor

Don't memorize these — read on demand.

## Codex CLI Specific Notes

Codex CLI runs commands directly via shell, so:

- All shell scripts work natively — no special wrapper needed
- **No PreToolUse equivalent** — protection is via the `check-secrets.sh` invocation pattern (always call it before commit/push)
- For three-layer defense, configure git hooks:
  ```bash
  git config core.hooksPath ~/.local/share/git-skill/scripts
  ```
  This makes even raw `git commit` invoke `precommit-guard.sh`.
