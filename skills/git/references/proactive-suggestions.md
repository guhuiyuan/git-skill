# Proactive Suggestions — When to Suggest Project Management Actions

This skill is **proactive**, not just reactive. When Claude is helping you work on a project, it will surface relevant git operations at natural breakpoints. This document explains the detection rules.

## How it works

The skill includes `proactive-advisor.sh` (and `.ps1`) which inspects:

1. **Repository state** — uncommitted changes, branches, ahead/behind remote
2. **Project shape** — language markers, presence of `.gitignore` / README / LICENSE
3. **Sensitive patterns** — files that look like secrets in working tree
4. **Workflow hints** — keywords you use ("refactor", "hotfix", "release")

Claude calls this script at natural breakpoints (e.g., after editing several files, when you ask about progress, when work seems complete) and surfaces relevant suggestions.

## Trigger rules (priority HIGH → LOW)

### 🔴 HIGH (action recommended now)

| Condition | Suggestion | Why |
|---|---|---|
| ≥10 uncommitted files accumulated | `/git commit -m "..."` | Risk of losing work / merge conflicts grows |
| Project type detected (Node/Python/Java/Go/Rust/.NET) but no `.gitignore` | `/git gitignore` | Build artifacts will pollute commits |
| ≥5 commits ahead of remote | `/git push && /git pr new` | Work is stranded locally; team can't see it |
| Local repo with commits but no remote | `/git create-repo --platform <github\|gitee>` | No backup, no collaboration |
| Sensitive files in working tree (`.env`, `*.pem`, etc.) | `/git scan && add to .gitignore` | One accidental commit = secret leak |

### 🟡 MEDIUM (consider doing soon)

| Condition | Suggestion | Why |
|---|---|---|
| 5-9 uncommitted files | `/git commit -m "..."` | Atomic commits are easier to review |
| ≥3 source files but no README | `/git readme` | Visitors / future-you need docs |
| No LICENSE file | `/git license` | Legal clarity for users |
| 1-4 commits ahead of remote | `/git push` | Backup + collaboration |
| Branch older than 14 days | `/git rebase <default-branch>` | Reduces merge pain |

### 🟢 LOW (hygiene)

| Condition | Suggestion | Why |
|---|---|---|
| Merged branches present | `/git branch delete <name>` | Reduce clutter |
| On non-default branch with uncommitted work | `/git status` | Review before continuing |

## Workflow pattern triggers (natural language)

When the user's natural language contains certain phrases, Claude should suggest the matching workflow:

| User says something like | Claude suggests |
|---|---|
| "我要重构这个模块" / "I'm going to refactor" | "考虑新建 `chore/refactor-xxx` 分支,在分支上操作" |
| "紧急修复 bug" / "hot fix needed" | "考虑新建 `hotfix/xxx` 分支,快速走完评审/合并" |
| "发布一个版本" / "cut a release" | "考虑创建 tag + 走 release 分支流程" |
| "做个实验性改动" / "experimental" | "考虑新建 `experiment/xxx` 分支,失败可丢弃" |
| "写了一些测试" / "added tests" | "考虑单独 commit:`test: 覆盖 xxx`" |
| "更新文档" / "update docs" | "考虑单独 commit:`docs: ...`" |
| "清理无用代码" / "cleanup dead code" | "考虑单独 commit:`chore: remove unused ...`" |
| "修复了 xxx 但还没测" / "fixed but not tested" | "建议跑测试后 commit,或用 `git stash` 暂存" |

## Suggestion etiquette

Claude **does not**:

- Spam suggestions every turn (max 1 per category per turn)
- Suggest commit before you've made meaningful progress (avoid "commit empty work")
- Auto-commit anything (always asks first via AskUserQuestion)
- Override explicit user decisions ("先别 commit,我还要再改")

Claude **does**:

- Surface suggestions inline at natural breakpoints
- Group multiple suggestions by priority
- Provide the exact command so you can copy-paste
- Let you dismiss with "no thanks" / "skip for now" without nagging

## Disable proactive suggestions

If you find the suggestions annoying, you can disable them:

1. **Globally**: in `~/.claude/settings.json`, add:
   ```json
   {
     "permissions": {
       "deny": ["Bash(${CLAUDE_SKILL_DIR}/scripts/proactive-advisor.sh:*)"]
     }
   }
   ```
2. **Per-session**: at conversation start, say "no proactive git suggestions this session".

## Extend the rules

To add new rules, edit `scripts/proactive-advisor.sh` (and `.ps1`). Each rule is a single `add_suggestion` call. See the existing rules for the pattern.