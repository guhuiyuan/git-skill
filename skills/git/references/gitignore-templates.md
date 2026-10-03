# .gitignore Templates — Index and Usage

git-skill 内置 8 个核心语言/IDE/OS 模板,直接源自 [github/gitignore](https://github.com/github/gitignore) 风格(2026-09 最新)。

## 内置模板清单

| 文件 | 触发条件(检测) | 覆盖内容 |
|---|---|---|
| `node.gitignore` | `package.json` | `node_modules/`, `dist/`, `.env*`, npm logs, Yarn, pnpm |
| `python.gitignore` | `pyproject.toml` / `setup.py` / `requirements.txt` / `*.py` | `__pycache__/`, `*.pyc`, `.venv`, `.pytest_cache`, mypy, ruff |
| `java.gitignore` | `pom.xml` / `build.gradle*` / `*.java` | `target/`, `*.jar`, `.gradle/`, `.idea/`, `.classpath` |
| `go.gitignore` | `go.mod` / `go.sum` | vendor/ (by config), .env, build artifacts |
| `rust.gitignore` | `Cargo.toml` / `Cargo.lock` | `target/`, `**/*.rs.bk`, `.idea/` |
| `dotnet.gitignore` | `*.csproj` / `*.sln` | `bin/`, `obj/`, `*.user`, `*.suo` |
| `generic-ide.gitignore` | `.idea/` 或 `.vscode/` 已在工作树 | JetBrains, VS Code, Vim, Emacs, Sublime |
| `os.gitignore` | 总是应用 | `.DS_Store`, `Thumbs.db`, desktop.ini |

## 自动检测逻辑

`generate-gitignore.sh` 的检测顺序:

```bash
# Node.js
[[ -f package.json ]] && append node.gitignore

# Python
[[ -f pyproject.toml || -f setup.py || -f requirements.txt ]] && append python.gitignore

# Java
[[ -f pom.xml || -f build.gradle || -f build.gradle.kts ]] && append java.gitignore

# Go
[[ -f go.mod ]] && append go.gitignore

# Rust
[[ -f Cargo.toml ]] && append rust.gitignore

# .NET
shopt -s nullglob
[[ $(ls *.csproj *.sln 2>/dev/null) ]] && append dotnet.gitignore

# IDE
[[ -d .idea || -d .vscode ]] && append generic-ide.gitignore

# OS 总是追加
append os.gitignore
```

## 合并行为

**若 `.gitignore` 不存在** → 直接创建。

**若 `.gitignore` 存在**:

1. 备份:`mv .gitignore .gitignore.bak-$(date +%Y%m%d-%H%M%S)`
2. 合并模板 + 已有内容(去重)
3. 询问用户:append / 替换 / 取消

示例合并:

```bash
# 用户已有 .gitignore 包含:
my-local-file.log
*.tmp

# skill 检测到 Node.js,追加 node.gitignore:
node_modules/
dist/
.env*

# 最终:
my-local-file.log
*.tmp

# node
node_modules/
dist/
.env*
```

## 手动指定模板

```bash
/git gitignore python              # 单语言
/git gitignore node python java    # 多个合并
/git gitignore --list              # 列出所有内置模板
```

## 模板示例片段

**`node.gitignore`**(完整版本存 templates/gitignore/):

```gitignore
# Logs
logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*
lerna-debug.log*

# Build output
dist/
build/
*.tsbuildinfo

# Dependencies
node_modules/

# Environment
.env
.env.*
!.env.example

# Editor / OS
.vscode/
.idea/
.DS_Store
Thumbs.db

# Tests / Coverage
coverage/
.nyc_output/

# Cache
.npm/
.eslintcache
.cache/
.parcel-cache/
```

**`python.gitignore`**:

```gitignore
# Byte-compiled
__pycache__/
*.py[cod]
*$py.class

# Virtual envs
.venv/
venv/
env/
.python-version

# Distribution
build/
dist/
*.egg-info/
*.egg
MANIFEST

# Tooling caches
.mypy_cache/
.ruff_cache/
.pytest_cache/
.coverage
htmlcov/

# IDEs
.idea/
.vscode/
```

完整内容见 `templates/gitignore/` 目录。

## 进阶:扩展模板

skill 设计为可扩展:

1. 添加自定义模板:`templates/gitignore/custom-X.gitignore`
2. 重新运行 `/git gitignore --auto`(若检测到 marker 文件则自动应用)

或者:

3. 用 `--fetch` 从 github/gitignore 拉最新(需联网,WebFetch):

```bash
/git gitignore --fetch --template python
```

## 不会自动生成的内容

以下内容需手动添加(避免误屏蔽重要文件):

```gitignore
# 1. 用户专属工具输出(项目特定)
your-tool-output/

# 2. 本地调试文件
local-debug.log

# 3. 临时 scratch
scratch/
```

## 验证

生成后验证:

```bash
/git gitignore --auto
# 输出:已添加 6 个模板:node, python, generic-ide, os

git status
# .gitignore 应为 untracked(新增)或 modified(若已存在)

cat .gitignore
# 应包含上面示例中的核心模式
```

## 与 secret 扫描的协同

skill 优先用 `.gitignore` + secret 扫描双重防御:

1. **第一道防线**:secret 文件名(如 `.env`)进 `.gitignore`,根本不上 staged area
2. **第二道防线**:即使绕过,secret 内容扫描仍能识别 AWS/GitHub PAT 等模式

正确的工作流:

```bash
# 1. 项目初始化时一次性生成 .gitignore
/git init
/git gitignore --auto

# 2. 创建 .env(它会被 .gitignore 自动忽略)
echo "DATABASE_URL=postgres://..." > .env

# 3. .env 永远不会出现在 git status 中
git status  # 只有 .env.example(模板),不会被误传
```

## 参考资源

- github/gitignore 官方: <https://github.com/github/gitignore>
- gitignore.io(API + UI): <https://www.toptal.com/developers/gitignore>
- 官方文档: <https://git-scm.com/docs/gitignore>