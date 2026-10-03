# Git Skill — 通用 Git 项目管理 Skill

> 一站式 git 项目管理工具:本地仓库 ↔ GitHub / Gitee 的端到端工作流,内置三层敏感信息扫描、自动化 `.gitignore` / `README` / `LICENSE` 生成、主动建议。**通用到任何项目都能 clone 即用**。

支持 **Claude Code / Cursor / Codex CLI** 三个 AI agent;底层脚本(`*.sh` + `*.ps1`)也可独立命令行调用。

---

## ✨ 核心特性

- 🔒 **三档安全防护**:`CRITICAL` 硬阻断 / `HIGH` 默认阻断可 force / `LOW` 仅警告 — 自动识别 `.env`、私钥、AWS / GitHub / OpenAI / Anthropic / Stripe / Google 等 token
- 🤖 **跨 AI agent 兼容**:Claude Code(`SKILL.md`)、Cursor(`.mdc` 规则)、Codex CLI(`AGENTS.md`)一份脚本三处用
- 💬 **双模式触发**:自然语言("把项目上传到 gitee 仓库")或 `/git <verb>`(`/git push`)均可
- 🌐 **平台双轨**:GitHub(`gh` CLI 优先)与 Gitee(`oschina/gitee-cli` 优先),adapter 模式可扩展 GitLab
- 🛡️ **三层防护架构**:gitleaks 二进制(160+ 规则)→ 内置精简规则兜底 → PreToolUse hook 独立拦截
- 🧠 **主动建议**:检测到 uncommitted changes、缺 README/LICENSE、敏感文件、远程 ahead/behind 等状态时,**主动建议**下一步操作
- 📦 **项目脚手架**:自动检测语言(8 种 + IDE + OS)生成 `.gitignore`,3 档 README 模板,5 种 LICENSE 模板
- 🚀 **零外部依赖**:仅需 `git`,可选 `gitleaks` / `gh` / `gitee-cli`(自动检测,有则用)

---

## 🚀 三步安装

### 1️⃣ 克隆仓库

```bash
git clone https://github.com/<owner>/git-skill.git ~/src/git-skill
cd ~/src/git-skill
```

### 2️⃣ 选择你的 AI agent,跑对应安装脚本

| AI Agent | 命令 | 入口文件 | 部署位置 |
|---|---|---|---|
| **Claude Code** | `./install.sh` (macOS/Linux) / `.\install.ps1` (Win) / `install.cmd` (CMD) | `SKILL.md` | `~/.claude/skills/git/` |
| **Cursor** | `./install-cursor.sh` | `compat/cursor/git.mdc` | `~/.cursor/rules/git.mdc` |
| **Codex CLI** | `./install-codex.sh` | `compat/codex/AGENTS.md` | `~/.codex/AGENTS.md` |

三个安装脚本**自动共享同一份脚本**(优先复用 `~/.claude/skills/git/`,避免重复)。

### 3️⃣ 重启 agent

- **Claude Code**:重启后 `/git <verb>` 即可
- **Cursor**:重启,打开项目后说"commit 这些变更"
- **Codex CLI**:重启,任意 git 项目里说"帮我推到 GitHub"

---

## ⚡ 快速开始

### 自然语言(任意 agent)

```
帮我把这个项目上传到 gitee 仓库
提交一下,信息是 feat: initial commit
扫描有没有敏感文件不能上传
新建一个 feature-x 分支
提个 PR 到 main
```

### Claude Code slash 命令(`/git <verb>`)

```bash
/git init               # 初始化(自动生成 .gitignore)
/git add .
/git commit -m "..."    # 自动敏感扫描
/git push -u origin main
/git create-repo --platform github --name my-app --public
/git issue new --title "..."
/git pr new --title "..."
/git scan               # 仅跑敏感扫描
/git auth               # 触发认证引导
/git help
```

完整 verb 列表见 [skills/git/references/command-reference.md](skills/git/references/command-reference.md)。

---

## 🛡️ 安全特性(★ 核心)

skill 自动检测常见敏感信息,**任何 commit / push 前自动扫描**。

### 三档 severity

| 等级 | 默认行为 | 绕过 |
|---|---|---|
| 🔴 **CRITICAL**(真实密钥)| **永远阻断** | ❌ 不可绕过 |
| 🟡 **HIGH**(疑似密钥)| 阻断 | ✅ `--force-allow-high` |
| 🟢 **LOW**(敏感但不致命)| 仅警告 | ✅ 继续 |

### 三层防护

```
Layer 1: PreToolUse hook (Claude Code,可选)
  ↓ 拦截裸 `git commit` / `git push`
  ↓ 即使不走 skill 也兜底

Layer 2: skill 流程内嵌扫描
  ↓ /git commit / push 自动跑
  ↓ 任何 commit 必经此关

Layer 3: gitleaks 二进制(160+ 规则)
  ↓ 优先调用,未装时降级内置 20 条规则
  ↓ 服务端 push protection 兜底
```

详细规则见 [skills/git/references/secret-patterns.md](skills/git/references/secret-patterns.md)。

### 推荐安装 gitleaks(覆盖率 25% → 90%+)

```bash
brew install gitleaks        # macOS
scoop install gitleaks       # Windows
# Linux: https://github.com/gitleaks/gitleaks/releases
```

---

## 🔑 认证(★ token 存储红线)

**强烈推荐**:用 OS keychain,**绝不**把 token 写到任何文件、`.zshrc`、`.bashrc` 或 commit 中。

| OS | 配置方法 |
|---|---|
| macOS | `gh auth login` 自动存 Keychain |
| Windows | `gh auth login` 自动存 Credential Manager |
| Linux | `gh auth login` + OAuth / `secret-tool`(libsecret) |

### 备用:SSH 密钥

```bash
ssh-keygen -t ed25519 -C "you@example.com"
# 把 ~/.ssh/id_ed25519.pub 贴到:
#   GitHub: https://github.com/settings/keys
#   Gitee:  https://gitee.com/profile/sshkeys
```

详细对比见 [skills/git/references/auth-guide.md](skills/git/references/auth-guide.md)。

---

## 🌐 平台支持

| 平台 | 状态 | 认证方式 | adapter |
|---|---|---|---|
| **GitHub** (github.com, *.ghe.com) | ✅ v1 完整支持 | `gh` CLI / Fine-grained PAT / SSH | `_platform/github.sh` |
| **Gitee** (gitee.com) | ✅ v1 完整支持 | `oschina/gitee-cli` / Personal Token / SSH | `_platform/gitee.sh` |
| GitLab / GitCode / Bitbucket | 🔜 v2 规划 | — | (预留接口) |

Gitee 与 GitHub 的 7 大 API 差异:[skills/git/references/platform-gitee.md](skills/git/references/platform-gitee.md)。

---

## 📚 文档索引

### 工作流与命令

- [skills/git/references/workflows.md](skills/git/references/workflows.md) — 6 种典型场景
- [skills/git/references/command-reference.md](skills/git/references/command-reference.md) — 完整 verb 清单
- [skills/git/references/gitignore-templates.md](skills/git/references/gitignore-templates.md) — `.gitignore` 模板索引

### 安全与认证

- [skills/git/references/secret-patterns.md](skills/git/references/secret-patterns.md) — 20 条内置规则
- [skills/git/references/gitleaks.toml](skills/git/references/gitleaks.toml) — gitleaks 自定义配置
- [skills/git/references/auth-guide.md](skills/git/references/auth-guide.md) — 认证 + OS keychain

### 平台与兼容性

- [skills/git/references/platform-gitee.md](skills/git/references/platform-gitee.md) — Gitee vs GitHub API
- [skills/git/references/platform-compat.md](skills/git/references/platform-compat.md) — Windows / macOS / Linux

### 智能与排错

- [skills/git/references/proactive-suggestions.md](skills/git/references/proactive-suggestions.md) — 主动建议触发规则
- [skills/git/references/troubleshooting.md](skills/git/references/troubleshooting.md) — 12 个高频错误

---

## 🧪 离线运行(无 AI agent)

所有脚本是**平台无关的命令行工具**。即使不用任何 AI agent,也能直接调用:

```bash
# Secret scan
~/.claude/skills/git/scripts/check-secrets.sh --staged --severity critical,high

# Generate .gitignore
~/.claude/skills/git/scripts/generate-gitignore.sh --auto

# Branch flow
~/.claude/skills/git/scripts/git-branch-flow.sh new feature-x --from main

# PowerShell 等价
~/.claude/skills/git/scripts/check-secrets.ps1 --severity critical
```

每个脚本都支持 `--help`、`--json`、`--dry-run`、`--force-allow-high`。

---

## 🤝 跨 AI agent 工作原理

```
            ┌─────────────────────────────────────┐
            │  skills/git/scripts/*.sh + *.ps1   │ ← 共享脚本
            └────────────┬────────────────────────┘
                         │
        ┌────────────────┼─────────────────────┐
        ↓                ↓                     ↓
┌───────────────┐ ┌──────────────┐ ┌──────────────────┐
│ Claude Code   │ │ Cursor       │ │ Codex CLI        │
│ SKILL.md      │ │ git.mdc      │ │ AGENTS.md        │
│ ~/.claude/... │ │ ~/.cursor/.. │ │ ~/.codex/...     │
└───────────────┘ └──────────────┘ └──────────────────┘
```

三个入口各自由对应 agent 扫描;底层脚本**只装一份**(`install.sh` 优先;Cursor/Codex 安装脚本自动复用)。

---

## 🗑️ 卸载

```bash
./uninstall.sh             # macOS / Linux / Git Bash
.\uninstall.ps1            # Windows PowerShell
./install-cursor.sh --uninstall  # Cursor(若已加)
./install-codex.sh --uninstall   # Codex(若已加)
```

---

## 🤝 贡献与安全

- 贡献指南:[CONTRIBUTING.md](CONTRIBUTING.md)
- 漏洞 / 误检反馈:[SECURITY.md](SECURITY.md)(**请附 hash 而非 secret 本身**)

---

## 📜 License

[MIT](LICENSE) — 2026 Git Skill Maintainers