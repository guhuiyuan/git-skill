# Workflows — 6 Typical Scenarios

git-skill 优先提供**端到端工作流**,而不是零散的命令。这里是 6 个最常用的流程,每个都能用 `/git <verb>` 一系列命令或一条自然语言描述触发。

---

## A. 全新本地项目上传到 GitHub

适用于"我在本地刚写完一个项目,要发到 GitHub"。

**自然语言触发**:
> "把当前项目上传到 GitHub"
> "把这个本地项目推到我 GitHub 账号里"

**手动流程**:

```bash
# 1. 初始化本地仓库
/git init --branch main

# 2. (可选) 自动检测语言 + 生成 .gitignore
/git gitignore --auto

# 4. 添加文件并提交
/git add .
/git commit -m "feat: initial commit"

# 5. 创建远程仓库
/git create-repo --platform github --name my-app --public --description "..."

# 6. 推送到远程
/git push -u origin main
```

**自动触发路径**(若你直接说"上传到 GitHub"):

Claude 识别意图 → 跑上述 6 步。无需用户记忆命令。

**注意事项**:

- **不要忘记 `.gitignore`** — 否则会误传 `node_modules` 等
- skill 会在 commit 前自动跑 secret 扫描
- skill 会在 push 前再跑一次(`push` 阶段通常会重新审 staging area)

---

## B. 全新本地项目上传到 Gitee

适用场景同 A,但平台是 Gitee。

**关键差异**:

| 维度 | GitHub | Gitee |
|---|---|---|
| CLI 工具 | `gh` | `gitee` (oschina/gitee-cli) |
| 默认分支 | `main` | `master`(API 行为,2026 仍如此) |
| 认证 header | `Authorization` | `?access_token=` query |
| 远程 URL | `github.com` | `gitee.com` |

**自然语言触发**:
> "把这个项目上传到 Gitee"
> "把当前目录发布到码云仓库"

**手动流程**:

```bash
# 1-4 同 A
/git init --branch master
/git gitignore --auto
/git readme   # 可选
/git commit -m "feat: initial commit"

# 5. 创建 Gitee 仓库(注意 --platform)
/git create-repo --platform gitee --name my-app --public

# 6. 推送到 Gitee
/git push -u origin master   # 注意 master!
```

**Gitee 私有部署**:

```bash
/git create-repo --platform gitee \
  --name my-app \
  --host gitee.example-corp.com   # 企业私有 Gitee
```

---

## C. 已有本地项目推到新远程

适用于"我已经有一个 git 项目,但 remote URL 错了 / 想换远程 / 想加第二个 remote"。

**自然语言触发**:
> "把项目推到 git@github.com:myuser/my-app.git"
> "再加一个 gitee 远程"

**手动流程**:

```bash
# 1. 查看现有 remote
/git remote list

# 2. 添加 remote
/git remote add origin git@github.com:myuser/my-app.git
# 或:
/git remote add github git@github.com:myuser/my-app.git
/git remote add gitee  git@gitee.com:myuser/my-app.git

# 3. 推送
/git push -u github main
/git push -u gitee main

# 4. 后续推所有 remote
/git push --all
```

**常见错误**:

- **远程已有 commit 而本地没有**:先 `git pull --rebase`,再 push
- **默认分支不匹配**(本地 main, 远程 master):`git push -u origin main:main`
- **权限不足**:确认 token scope / SSH key 已注册

---

## D. 日常分支开发

适用于"我要开发一个 feature,最后提个 PR"。

**GitHub Flow**(推荐,简洁):

```bash
# 1. 从 main 拉新分支
/git branch new feature/login-form --from main

# 2. 开发(任意时长)
/git add .
/git commit -m "feat(login): add form validation"
# 多次 commit 都可以

# 3. 推送分支
/git push -u origin feature/login-form

# 4. 创建 PR
/git pr new \
  --title "feat: login form with validation" \
  --body-file PR_BODY.md \
  --base main

# 5. 收到 review 评论后,继续 commit 到同一分支
/git add .
/git commit -m "fix(login): address review comments"
/git push

# 6. PR 合并后,清理本地 + 远程分支
/git branch delete feature/login-form
/git remote prune origin
```

**git-flow**(适合有版本发布的项目):

```bash
# 1. 从 main 切到 develop(若未存在)
/git branch new develop --from main
/git push -u origin develop

# 2. 从 develop 切 feature 分支
/git branch new feature/x --from develop
/git push -u origin feature/x

# 3. 完成 feature 后,合并回 develop
/git checkout develop
/git merge --no-ff feature/x -m "Merge feature/x into develop"

# 4. 准备 release
/git branch new release/v1.2.0 --from develop
# 在 release 分支修 bug
/git checkout main
/git merge --no-ff release/v1.2.0 -m "Release v1.2.0"
/git tag v1.2.0 --message "v1.2.0 release"
/git checkout develop
/git merge --no-ff release/v1.2.0

# 5. 紧急修复
/git branch new hotfix/critical --from main
# fix
/git checkout main
/git merge --no-ff hotfix/critical
/git tag v1.2.1
/git checkout develop
/git merge --no-ff hotfix/critical
```

**Conventional commit 类型**(skill 推荐):

| 类型 | 用途 |
|---|---|
| `feat:` | 新功能 |
| `fix:` | 修 bug |
| `docs:` | 文档 |
| `style:` | 格式调整(无逻辑变化) |
| `refactor:` | 重构 |
| `perf:` | 性能优化 |
| `test:` | 测试 |
| `chore:` | 构建/工具 |
| `ci:` | CI/CD |

**完整模板**:`<type>(<scope>): <subject>`,subject 50 字以内,body 72 字/行。

---

## E. 误提交了 secret 怎么办

**这是高风险场景**。一旦 secret 进入 git 历史,即使后续删除也仍可能泄露。

**步骤**:

1. **立即轮换 secret**(在平台重新生成,让旧 secret 失效)
   - GitHub PAT: <https://github.com/settings/personal-access-tokens>
   - AWS key: <https://console.aws.amazon.com/iam/>
   - OpenAI/Anthropic:对应 dashboard

2. **从当前 commit 删除**(本地干净):

```bash
# 如果 secret 还在 working tree:
echo "secret-file.txt" >> .gitignore
git rm --cached secret-file.txt
/git commit -m "fix: remove leaked secret"
```

3. **从 git 历史彻底删除**(慎重,会改写历史):

```bash
# 用 git filter-repo(2026 推荐工具,比 filter-branch 快 100x)
pip install git-filter-repo

# 删除特定文件:
git filter-repo --path secret-file.txt --invert-paths

# 替换特定文本(改写 API key):
git filter-repo --replace-text expressions.txt
# expressions.txt:
# AKIAIOSFODNN7EXAMPLE==>AWS_KEY_REDACTED

# 强制推送(危险,需要团队同步)
/git push --force --all origin
/git push --force --tags origin
```

4. **如果已经推到 GitHub,使用 BFG 或 GitHub Secret Scanning**:

- GitHub 自动检测已知 token 模式,会发邮件 + 阻断 push
- 如果 GitHub 没自动检测,自己触发:"Report abuse" 或 "Remove sensitive data"
- GitHub: <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository>

5. **PR / issue 评论泄露**:

- GitHub: `gh api -X DELETE <repo>/issues/comments/<id>`
- Gitee: Gitee API v5 + admin 权限

**❌ 错误做法**:

- 只改文件、不轮换 token(已被获取)
- 以为加进 .gitignore 就好(历史 commit 还在)
- push --force 但没通知团队(队友历史还包含旧 secret)
- 给一个仓库清完了,另一个镜像仓库没清

---

## F. 生成 .gitignore / README / LICENSE

**自然语言触发**:
> "帮我生成 .gitignore"
> "给项目加个 README"
> "加个 MIT LICENSE"

**手动流程**:

```bash
# 1. 自动检测语言 + 生成 .gitignore
/git gitignore --auto
# 等价于:检测 package.json → 用 node.gitignore;检测 pyproject.toml → python.gitignore;...
# 多语言混用时,合并多个模板

# 2. 指定语言
/git gitignore python
/git gitignore node python java    # 多个合并

# 3. 生成 README(3 档)
/git readme --style minimal
/git readme --style standard   # 默认
/git readme --style detailed

# 4. 生成 LICENSE
/git license --type MIT
/git license --type Apache-2.0 --name "Your Name" --year 2026
```

**与现有文件合并**:

- 若 `.gitignore` 存在,询问:append / 备份覆盖 / 取消
- 若 `README.md` 存在,警告并询问:append / 备份 / 取消
- 若 `LICENSE` 存在,**拒绝覆盖**(LICENSE 一旦 commit 就是法律文件)

**`.gitignore` 模板索引**:详见 [gitignore-templates.md](gitignore-templates.md)

---

## 跨工作流模式

### 推送前检查

skill 默认在以下时机跑 secret 扫描:

1. `/git commit -m "..."` 之前
2. `/git push` 之前
3. PreToolUse hook(可选启用,见 README 配置示例)

绕开方式(仅 HIGH 级别可强制):

```bash
/git commit --force-allow-high -m "..."    # HIGH 级别强制
```

CRITICAL 级别**不可绕过**。

### 安全恢复点

误操作前先建 stash / tag:

```bash
# 任何可能改写历史前
/git tag backup-before-merge
/git stash push -u   # 包括 untracked 文件

# 误操作回滚
/git stash pop
git checkout backup-before-merge
```

### 性能优化

大仓库(`>1GB` 历史或 `>100k` commit):

```bash
git maintenance run --gc        # 清理
git config --global feature.manyFiles true  # 大仓库优化
```

---

## 自动化:Proactive Advisor

skill 在每个 git 操作前后自动运行 `proactive-advisor.sh`,在合适时机**主动建议**:

- 检测到 uncommitted changes 超过阈值 → 建议 commit
- 检测到 main 分支落后 remote → 建议 pull
- 检测到 PR 已合并、对应分支还在 → 建议删除
- 检测到项目缺少 README/LICENSE → 建议生成
- 检测到文件特征符合某语言 → 建议生成对应 .gitignore

详见 [proactive-suggestions.md](proactive-suggestions.md)。

---

## 进一步参考

- `references/command-reference.md` — 完整 verb 列表
- `references/auth-guide.md` — 认证设置
- `references/troubleshooting.md` — 常见错误修复
- `references/secret-patterns.md` — secret 扫描规则细节