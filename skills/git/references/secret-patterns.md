# Secret Patterns — Embedded Fallback Rules

This document lists the 20 high-hit patterns that git-skill uses when **gitleaks is not installed**. When gitleaks IS installed, skill uses gitleaks' own 160+ rule set instead.

**Strongly recommended**: install gitleaks for comprehensive coverage.

```bash
brew install gitleaks      # macOS
scoop install gitleaks     # Windows
winget install gitleaks    # Windows
# Linux: https://github.com/gitleaks/gitleaks/releases
```

## Filename rules

### 🔴 CRITICAL (always blocks)

| Pattern | Why |
|---|---|
| `.env`, `.env.*` | Environment files with secrets |
| `*.pem`, `*.key`, `*.p12`, `*.pfx` | Cryptographic material |
| `id_rsa`, `id_rsa.*`, `id_ed25519`, `id_ed25519.*`, `id_dsa`, `id_ecdsa` | SSH private keys |
| `*.keystore` | Java keystores |
| `credentials.json` | Often contains AWS/GCP creds |
| `service-account.json` | GCP service account keys |
| `.npmrc` | Often contains _authToken |
| `.pypirc` | PyPI credentials |
| `.netrc` | Plaintext credentials |
| `pgpass` | PostgreSQL password file |
| `gha-creds-*` | GitHub Actions credentials |

### 🟡 HIGH (blocks unless `--force-allow-high`)

| Pattern | Why |
|---|---|
| `*.secret`, `*secret*` | Generic secret file names |
| `*password*`, `*credential*` | Often credential files |
| `*.sqlite`, `*.db` | Database files may contain PII |
| `*.bak`, `*.swp` | Backup files often contain original secrets |
| `.DS_Store` | macOS metadata (privacy concern) |

### 🟢 LOW (warn only)

| Pattern | Why |
|---|---|
| `*.log`, `*.tmp` | Often contains runtime info |
| `node_modules`, `venv`, `__pycache__` | Should be in .gitignore anyway |
| `target`, `build`, `dist` | Build artifacts |

## Content rules (in staged diff)

### 🔴 CRITICAL

| Rule | Regex | Examples |
|---|---|---|
| AWS Access Key | `AKIA[0-9A-Z]{16}` | `AKIAIOSFODNN7EXAMPLE` |
| AWS Secret Key | `aws_secret_access_key[=:]["']?[A-Za-z0-9/+=]{40}` | `aws_secret_access_key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| GitHub PAT | `ghp_[A-Za-z0-9]{36}` | `ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` |
| GitHub Fine-grained PAT | `github_pat_[A-Za-z0-9_]{82}` | `github_pat_11AAAAAA...` |
| GitHub OAuth | `gho_[A-Za-z0-9]{36}` | |
| GitHub User Token | `ghu_[A-Za-z0-9]{36}` | |
| GitHub Server Token | `ghs_[A-Za-z0-9]{36}` | |
| GitHub Refresh Token | `ghr_[A-Za-z0-9]{36}` | |
| OpenAI API Key | `sk-[A-Za-z0-9]{20,}` | `sk-...` |
| OpenAI Project Key | `sk-proj-[A-Za-z0-9_-]{40,}` | |
| Anthropic API Key | `sk-ant-[A-Za-z0-9_-]{40,}` | |
| Private Key | `-----BEGIN (RSA \|EC \|DSA \|OPENSSH \|PGP )?PRIVATE KEY-----` | |
| Stripe Live Secret | `sk_live_[0-9a-zA-Z]{24,}` | |
| Stripe Live Restricted | `rk_live_[0-9a-zA-Z]{24,}` | |
| Google API Key | `AIza[0-9A-Za-z_-]{35}` | |
| JWT Token | `eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+` | |
| Slack Token | `xox[baprs]-[0-9]{10,}-[0-9]{10,}-[A-Za-z0-9]{24,}` | |

### 🟡 HIGH

| Rule | Regex |
|---|---|
| Generic password | `(password\|passwd\|pwd)[=:]["'][^"']{8,}["']` |
| Generic API key | `(api[_-]?key\|token\|secret)[=:]["'][A-Za-z0-9_\-]{16,}["']` |

## Coverage estimate

The embedded rules cover approximately the **top 25% of common secret types** seen in real-world repositories. The remaining 75% are covered by:

- **gitleaks binary** (preferred) — 160+ rules
- **Server-side push protection** (GitHub/Gitee) — runs on push, blocks known patterns
- **PreToolUse hook** — catches commands even when not going through skill

## False positives

The skill excludes these paths from content rules:

- `*.example`, `*.sample`, `*.template`
- `*.test`, `*.fixture`
- `*.md`, `LICENSE`, `.gitignore`

If you encounter a false positive not covered by these exclusions:

1. Open an issue: <https://github.com/<owner>/git-skill/issues>
2. **Do NOT include the actual secret** in your report
3. Include the pattern (e.g., `password = "..."`) and a SHA-256 hash of the file

## Severity tiers (recap)

| Level | Default | Override |
|---|---|---|
| 🔴 CRITICAL | Block | Cannot bypass |
| 🟡 HIGH | Block | `--force-allow-high` |
| 🟢 LOW | Warn | Always allowed |