# Command Reference — Complete Verb List

所有 `/git <verb>` 命令的完整列表。**自然语言触发**等价于一个或多个 verb 的组合。

> 提示:多数 verb 有别名。`/git ci` ≡ `/git commit`,`/git br` ≡ `/git branch`。

## 一览

| Verb | 别名 | 用途 |
|---|---|---|
| `init` | | 初始化仓库 |
| `clone` | `cl` | 克隆远程仓库 |
| `add` | | 添加文件到 staging area |
| `commit` | `ci` | 提交 |
| `push` | `ps` | 推送到远程 |
| `pull` | `pl` | 拉取远程变更 |
| `fetch` | `f` | 仅下载远程变更,不合并 |
| `branch` | `br` | 分支管理 |
| `switch` | `sw` | 切换分支(只读 git switch) |
| `merge` | `mg` | 合并分支 |
| `rebase` | `rb` | 变基 |
| `tag` | | 标签管理 |
| `stash` | `st` | 暂存 |
| `log` | | 查看提交历史 |
| `status` | `st` | 查看工作区状态 |
| `diff` | `df` | 查看变更 |
| `remote` | `rmt` | 远程仓库管理 |
| `config` | `cfg` | git config |
| `restore` | `rst` | 恢复文件 |
| `reset` | `rst` | 重置(慎用) |
| `issue` | `is` | Issue 管理 |
| `pr` | | Pull Request 管理 |
| `create-repo` | `cr` | 在平台创建远程仓库 |
| `scan` | | 手动触发 secret 扫描 |
| `auth` | | 认证检查 / 引导 |
| `gitignore` | `gi` | 生成 .gitignore |
| `readme` | `rm` | 生成 README |
| `license` | `lic` | 生成 LICENSE |
| `workflows` | `wf` | 查看常用工作流(本文件) |
| `help` | `h`, `?` | 帮助 |

---

## 详细说明

### `/git init`

```bash
/git init                              # 默认初始化(branch: main)
/git init --branch master              # 指定初始分支
/git init --bare                       # bare 仓库
```

**自动行为**:
- 探测已有 `.git` → 提示已初始化,询问是否 reset
- 检测项目语言,自动建议 `.gitignore`

---

### `/git clone`

```bash
/git clone <url>
/git clone <url> --depth 1             # shallow clone
/git clone <url> <directory>           # 指定本地目录
```

**自动行为**:
- 检测 `https://github.com/...` → 自动设置为 GitHub 平台
- 检测 `git@gitee.com:...` → 自动设置为 Gitee 平台

---

### `/git add`

```bash
/git add .                             # 添加所有变更
/git add <pathspec>                    # 添加特定文件/目录
/git add -p                            # 交互式暂存
/git add -A                            # 包括删除
```

**自动行为**:
- `add .` 之后自动跑 `git status`,提示用户审核

---

### `/git commit` (`/git ci`)

```bash
/git commit -m "feat: add login"
/git commit --amend                    # 修改上次提交
/git commit --no-verify                # 跳过 hooks
/git commit --force-allow-high -m "..." # 强制跳过 HIGH 级别 secret
```

**自动行为**:
1. **扫描 staged diff** — secret 扫描
   - gitleaks 优先 → 内置规则兜底
   - CRITICAL 阻断,HIGH 阻断(除非 `--force-allow-high`),LOW 警告
2. 检查 commit message 格式(conventional commit)
3. 提示用户 commit 后操作(push? PR?)

---

### `/git push` (`/git push`)

```bash
/git push                              # push 当前分支
/git push -u origin main               # 首次 push 并设置 upstream
/git push --all                        # 推送所有分支
/git push --tags                       # 推送所有标签
/git push --force                      # 强制(会确认!)
/git push --force-with-lease           # 安全的 force
/git push --dry-run                    # 预览,不实际推送
```

**自动行为**:
1. **再扫一次 secret**(防 amend 绕过)
2. 检测 main/master push → 警告 + 询问确认
3. 检测 `--force` → 二次确认

---

### `/git pull`

```bash
/git pull                              # 拉取并 merge
/git pull --rebase                     # 拉取并 rebase(推荐)
/git pull --rebase --autostash         # 自动 stash
/git pull <remote> <branch>
```

---

### `/git branch` (`/git br`)

```bash
/git branch list                       # 列出分支
/git branch new <name>                 # 新建分支
/git branch new <name> --from main     # 从 main 创建
/git branch switch <name>              # 切换分支
/git branch delete <name>              # 删除(已合并)
/git branch delete <name> --force      # 强制删除
/git branch rename <old> <new>         # 重命名
/git branch prune                      # 清理 stale remote refs
```

**保护**:
- `delete main` / `delete master` → 强制二次确认
- `delete --force` → 二次确认

---

### `/git merge` (`/git mg`)

```bash
/git merge <branch>                    # merge 进当前分支
/git merge --no-ff <branch>            # 强制创建 merge commit
/git merge --squash <branch>           # squash merge
/git merge --abort                     # 中止冲突 merge
```

---

### `/git rebase` (`/git rb`)

```bash
/git rebase main                       # rebase 到 main
/git rebase -i HEAD~3                  # 交互式 rebase
/git rebase --abort
/git rebase --continue
```

**保护**:
- 检测到已推送的 commit → 警告 + 二次确认

---

### `/git tag`

```bash
/git tag list                          # 列出
/git tag <name>                        # 创建轻量标签
/git tag <name> --message "msg"        # 创建 annotated tag
/git tag <name> --annotate --sign      # GPG 签名
/git tag delete <name>                 # 删除
/git tag push <name>                   # 推送单个
/git tag push --all                    # 推送所有
```

---

### `/git stash` (`/git st`)

```bash
/git stash push                        # 暂存当前变更
/git stash push -u                     # 包括 untracked
/git stash push -m "msg"               # 带消息
/git stash list                        # 列出
/git stash pop                         # 应用并删除最新
/git stash apply                       # 应用但保留
/git stash drop                        # 删除最新
/git stash show -p <stash>             # 查看 diff
```

---

### `/git log`

```bash
/git log -n 10                         # 最近 10 条
/git log --oneline                     # 简短格式
/git log --graph                       # 图形
/git log --author=<name>
/git log --since="2 weeks ago"
/git log -p                            # 显示 diff
/git log -- <pathspec>
```

---

### `/git status` (`/git st`)

```bash
/git status                            # 完整状态
/git status --short                    # 简短
/git status --branch                   # 含分支 ahead/behind
```

---

### `/git diff` (`/git df`)

```bash
/git diff                              # working vs staging
/git diff --staged                     # staging vs HEAD
/git diff HEAD                         # working vs HEAD
/git diff <branch>                     # 当前 vs <branch>
```

---

### `/git remote` (`/git rmt`)

```bash
/git remote list                       # 列出
/git remote add <name> <url>           # 添加
/git remote remove <name>              # 删除
/git remote rename <old> <new>         # 重命名
/git remote set-url <name> <url>       # 修改 URL
/git remote prune                      # 清理 stale
/git remote get-url <name>             # 查看 URL
```

---

### `/git config` (`/git cfg`)

```bash
/git config user.name "Name"
/git config user.email "you@example.com"
/git config --global core.editor "vim"
/git config --list
/git config --unset <key>
```

---

### `/git issue` (`/git is`)

```bash
/git issue list [--state open|closed|all] [--limit N]
/git issue new --title "..." --body "..." [--labels bug,help]
/git issue new --body-file @BODY.md
/git issue view <number>
/git issue close <number>
/git issue comment <number> --body "..."
```

---

### `/git pr`

```bash
/git pr list [--state open|closed|merged|all]
/git pr new --title "..." --body "..." [--base main] [--draft]
/git pr view <number>
/git pr merge <number> [--squash|--rebase|--merge]
/git pr review <number> --body "..."
/git pr close <number>
```

---

### `/git create-repo` (`/git cr`)

```bash
/git create-repo --platform github --name my-app --public --description "..."
/git create-repo --platform gitee --name my-app --private
/git create-repo --platform github --name my-app --org my-org
```

---

### `/git scan`

```bash
/git scan                              # 扫描 staged diff
/git scan --working-tree               # 扫描工作树(未 staged 也算)
/git scan --all                        # 扫描所有 git 历史
/git scan --severity critical          # 只看 critical
/git scan --json                       # JSON 输出
/git scan --fix                        # 自动标记为 ignored
```

---

### `/git auth`

```bash
/git auth                              # 检测当前认证
/git auth --platform github           # GitHub 专检
/git auth --platform gitee             # Gitee 专检
/git auth --guide                      # 打印设置向导
/git auth --setup                      # 交互式配置(写入 keychain)
```

---

### `/git gitignore` (`/git gi`)

```bash
/git gitignore --auto                  # 自动检测
/git gitignore node                    # 指定语言
/git gitignore node python java        # 多个
/git gitignore --list                  # 列出内置
/git gitignore --fetch --template py   # 从网络获取最新
```

---

### `/git readme` (`/git rm`)

```bash
/git readme --style minimal
/git readme --style standard           # 默认
/git readme --style detailed
/git readme --name "My Project" --description "..."
```

---

### `/git license` (`/git lic`)

```bash
/git license --type MIT
/git license --type Apache-2.0 --name "Your Name" --year 2026
/git license --list                    # 列出可选项
```

**注意**:LICENSE 已存在 → 拒绝覆盖(法律文件)。

---

### `/git help` (`/git h`)

```bash
/git help                              # 列出 verb
/git help <verb>                       # verb 详细说明
/git help auth                         # 同 /git auth --guide
```

---

## 通用 Flag

所有 verb 都支持:

| Flag | 含义 |
|---|---|
| `--json` | 结构化输出 |
| `--dry-run` | 预览,不动手 |
| `--help` | 详细用法 |
| `--verbose` | 详细日志 |
| `--quiet` | 仅错误 |
| `--no-color` | 禁用颜色 |

---

## 退出码

| Code | 含义 |
|---|---|
| 0 | 成功 |
| 1 | 一般失败 |
| 2 | 被 secret 扫描阻断 |
| 3 | 用户取消 |
| 4 | 认证失败 |
| 5 | 网络错误 |

---

## 自然语言示例对照

| 你说的 | 等价 verb 序列 |
|---|---|
| "把这个项目推到 GitHub" | `init` + `gitignore` + `commit` + `create-repo --platform github` + `push` |
| "新建一个 feature 分支" | `branch new feature --from main` + `branch switch feature` |
| "提交一下,信息是 xxx" | `add .` + `commit -m "xxx"` |
| "扫描一下有没有密钥" | `scan` |
| "生成 .gitignore" | `gitignore --auto` |
| "提个 PR" | `pr new --title ...` |
| "看下 issue" | `issue list` |
| "认证设置" | `auth --guide` |
| "回滚一下" | `restore` 或 `reset --soft` + 询问 |

---

## 参考

- 各 verb 的具体用例:见 `references/workflows.md`
- 认证细节:见 `references/auth-guide.md`
- 平台差异:见 `references/platform-gitee.md`
- 错误修复:见 `references/troubleshooting.md`