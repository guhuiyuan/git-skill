---
name: git
description: |
  Git 项目管理助手:本地仓库与 GitHub/Gitee 之间的端到端工作流。当用户用自然语言说
  "把项目上传到 github/gitee"、"推到远程"、"新建/切换/删除分支"、"提交代码"、"提 PR"、
  "创建 issue"、"扫描有没有密钥/token 不要上传"、"生成 .gitignore / README / LICENSE" 时触发,
  或直接用 /git <subcommand> (init/add/commit/push/pull/clone/merge/rebase/tag/stash/
  branch/issue/pr/scan/readme/license/gitignore/auth/help/log/status/diff/remote/config) 时触发。
  触发关键词:git、提交、commit、push、pull、分支、branch、PR、pull request、issue、
  上传 GitHub、上传 Gitee、推送到、克隆、clone、敏感文件、密钥、token、.env、私钥。
  内置敏感信息扫描(.env、AWS/GitHub/OpenAI/Anthropic/Gitee token、私钥、JWT),
  优先调用 gitleaks 二进制,内置精简规则兜底。
license: MIT
compatibility: git >= 2.30, bash >= 4 (Git Bash on Windows), powershell >= 5 (Windows), gh CLI optional, oschina/gitee-cli optional, gitleaks optional (recommended)
metadata:
  version: 1.0.0
  author: git-skill maintainers
  repository: https://github.com/<owner>/git-skill
  platforms: github, gitee
allowed-tools: |
  Bash(git:*),
  Bash(${CLAUDE_SKILL_DIR}/scripts/*),
  Bash(gh:*),
  Bash(gitee:*),
  Bash(gitleaks:*),
  Bash(curl:*),
  Read,
  Edit,
  Write,
  Glob,
  Grep,
  AskUserQuestion,
  WebFetch(domain:github.com,gitee.com,api.github.com,gitee.com/api)
---

# Git Skill

A production-grade git workflow skill with built-in secret scanning and dual-platform support (GitHub + Gitee).

## What this skill does

Covers the full local-repo-to-remote lifecycle: `init` → `commit` → `push` → `branch` → `merge` → `tag` → `issue` → `PR`. Integrates with **GitHub** (via `gh` CLI) and **Gitee** (via `oschina/gitee-cli`). Automatically detects project language to generate `.gitignore`, prompts for `README` and `LICENSE`, and—**most importantly**—scans staged diffs for secrets before every `commit` and `push` with a **three-tier severity model**.

## When to use

### Natural language triggers

User can say any of these and Claude will activate this skill:

- "把项目上传到 github" / "推到 github" / "create a github repo"
- "把项目上传到 gitee" / "推到 gitee 仓库"
- "提交一下,信息是 xxx" / "git commit with message xxx"
- "新建一个 feature-x 分支" / "create branch xxx"
- "切换到 main 分支" / "switch to main"
- "合并 feature 分支" / "merge xxx"
- "提一个 PR 到 main" / "create pull request"
- "看一下 issue 列表" / "list issues"
- "检查有没有敏感文件不能上传" / "scan for secrets"
- "生成一个 .gitignore" / "create gitignore"
- "给这个项目加个 README" / "generate README"
- "提一个 license" / "add MIT license"
- "配置 git 用户名邮箱" / "git config user.name"
- "克隆这个仓库" / "clone xxx"

### Slash command triggers

`/git <verb> [args]` — primary command form. See [references/command-reference.md](references/command-reference.md) for full reference.

```
/git init           Initialize repo (auto .gitignore)
/git add <path>     Stage files
/git commit -m "x"  Commit (auto secret scan)
/git push           Push (auto secret scan)
/git pull --rebase  Pull with rebase
/git clone <url>    Clone a repo
/git branch new <name>     Create branch
/git branch switch <name>  Switch branch
/git branch list           List branches
/git merge <branch>        Merge
/git rebase <upstream>     Rebase
/git tag <name>     Tag
/git stash          Stash
/git status         Status
/git log -n 10      History
/git diff           Diff
/git remote add origin <url>   Add remote
/git config user.name "X"      Set config
/git issue new --title "x"   Create issue
/git issue list             List issues
/git pr new --title "x"      Create PR
/git pr list                 List PRs
/git scan           Run secret scan only
/git readme         Generate README
/git license        Generate LICENSE
/git gitignore      Generate .gitignore
/git auth           Trigger auth wizard
/git help           Show this help
```

### Quick start

```bash
cd my-project/
/git init           # Auto-detect language, generate .gitignore
/git readme         # Optional: generate README
/git license        # Optional: generate LICENSE
/git add .
/git commit -m "feat: initial commit"
/git create-repo --platform github --name my-project --public
/git push -u origin main
```

## Authentication (★ token storage red lines)

**Strongly recommended**: use your OS keychain. Never write tokens to `~/.zshrc`, `~/.bashrc`, commit them, or paste them in chat.

| OS | Storage |
|---|---|
| macOS | Keychain (default via `gh auth login`) |
| Windows | Credential Manager (default via `gh auth login`) |
| Linux | libsecret / `pass` |

Run `/git auth` for guided setup. Details: [references/auth-guide.md](references/auth-guide.md).

**❌ Never**:
- Write token to `~/.zshrc` / `~/.bashrc` (AI agents auto-collect, often leaked)
- Inline token in commands (`/git push --token ghp_xxx` — goes to shell history)
- Log token in any output

## Safety guarantees (★ three-tier + three layers)

### Three tiers

| Level | Default | Force override |
|---|---|---|
| 🔴 **CRITICAL** | Block, exit non-zero | **Still blocked** (cannot bypass; message: add to `.gitignore` or use secret manager) |
| 🟡 **HIGH** | Block | `--force-allow-high` allowed, but red stderr warning |
| 🟢 **LOW** | Warn, continue | Continue |

### Three layers

1. **Layer 1 — PreToolUse hook** (optional, in `~/.claude/settings.json`): even `git commit` outside `/git` is intercepted.
2. **Layer 2 — Skill flow scan**: `/git commit` and `/git push` always run `check-secrets.sh`.
3. **Layer 3 — gitleaks binary** (preferred): 160+ rules, composite rules, allowlists, `gitleaks:allow` commit message suppression.

If gitleaks is not installed, skill **falls back to embedded 20 high-hit patterns** (covers ~25% of cases). Install recommendation:

```bash
brew install gitleaks      # macOS
scoop install gitleaks     # Windows
winget install gitleaks    # Windows
# Linux: https://github.com/gitleaks/gitleaks/releases
```

Full pattern list: [references/secret-patterns.md](references/secret-patterns.md).

### Enable Layer 1 hook (optional)

Edit `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "${HOME}/.claude/skills/git/scripts/hook-precommit.sh"
      }]
    }]
  }
}
```

## Working directory rules

- Skill **always uses current cwd** as working directory.
- `detect-state.sh` checks `git rev-parse --is-inside-work-tree` at start.
- Non-git cwd only allows `init` and `clone` verbs.
- **Never** `cd` to other directories.
- **Never** recursively scan parent directories.
- Destructive operations (`reset --hard`, `branch -D`, `push --force`, `stash drop`) **always** trigger AskUserQuestion confirmation.

## Platform notes

GitHub vs Gitee key differences:

| Dimension | GitHub | Gitee |
|---|---|---|
| Default branch | `main` | `master` |
| Auth header | `Authorization: token <PAT>` | `?access_token=<PAT>` query |
| API style | REST + GraphQL | REST only |
| PR resource | `pull_request` | `pulls` |

Full table: [references/platform-gitee.md](references/platform-gitee.md).

## Workflows (summary)

| Workflow | Steps |
|---|---|
| A. New project → GitHub | `init` → `readme` → `license` → `add` → `commit` → `create-repo --platform github` → `push` |
| B. New project → Gitee | `init` → `readme` → `license` → `add` → `commit` → `create-repo --platform gitee` → `push` |
| C. Existing project → new remote | `remote add origin <url>` → `push -u` |
| D. Daily branch dev | `branch new x` → `add` → `commit` → `push` → `pr new` → `merge` |
| E. Secret in history | use `git filter-repo` (manual; see [references/workflows.md](references/workflows.md)) |
| F. Generate scaffolding | `gitignore` / `readme` / `license` (auto-detect language) |

Detailed steps: [references/workflows.md](references/workflows.md).

## Troubleshooting

6 common errors and fixes — see [references/troubleshooting.md](references/troubleshooting.md):

1. `Permission denied (publickey)` — SSH key not registered
2. `fatal: not a git repository` — cwd is not a git dir
4. `gitleaks: command not found` — falling back to embedded rules
5. `gh: not authenticated` — run `gh auth login`
6. `GITEE_TOKEN not set` — `export GITEE_TOKEN=...` or use CLI

## Uninstall

```bash
~/.claude/skills/git/uninstall.sh
```

Or:

```bash
rm -rf ~/.claude/skills/git
```

Then restart Claude Code.

## See also

- [references/workflows.md](references/workflows.md) — Detailed workflows
- [references/command-reference.md](references/command-reference.md) — Full command list
- [references/secret-patterns.md](references/secret-patterns.md) — 20 embedded rules
- [references/auth-guide.md](references/auth-guide.md) — GitHub/Gitee auth
- [references/platform-gitee.md](references/platform-gitee.md) — Gitee API differences
- [references/platform-compat.md](references/platform-compat.md) — Windows/macOS/Linux
- [references/troubleshooting.md](references/troubleshooting.md) — Common errors
- [references/gitignore-templates.md](references/gitignore-templates.md) — Language detection
- [references/proactive-suggestions.md](references/proactive-suggestions.md) — Proactive advisor rules

## Proactive suggestions (★ smart assistant)

This skill is **proactive**, not just reactive. At natural breakpoints in your work, Claude will surface relevant git operations. Examples:

- After you edit 10+ files → "考虑 `/git commit -m ...` 一下吗?"
- When your project has Node/Python/Java markers but no `.gitignore` → "考虑 `/git gitignore` 自动生成"
- When 5+ commits accumulate locally without push → "考虑 `/git push && /git pr new`"
- When you say "我要重构" / "hotfix" / "release" → suggest matching workflow branch
- When sensitive files appear in working tree → "考虑 `/git scan` + 加进 `.gitignore`"
- When long-lived branch (>14 days) → suggest rebase

Detection rules and triggers: [references/proactive-suggestions.md](references/proactive-suggestions.md).

Etiquette:

- Claude does **not** auto-commit; always asks via AskUserQuestion first
- Claude does **not** spam — max 1 suggestion per category per turn
- Claude does **not** override explicit user decisions

Disable: add to `~/.claude/settings.json`:

```json
{
  "permissions": {
    "deny": ["Bash(${HOME}/.claude/skills/git/scripts/proactive-advisor.sh:*)"]
  }
}
```