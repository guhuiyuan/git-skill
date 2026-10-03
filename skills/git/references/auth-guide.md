# Authentication Guide

> **TL;DR**: Use `gh auth login` (GitHub) or `gitee auth login` (Gitee). Your token is stored in the OS keychain automatically. Never write tokens to `~/.zshrc` or any file.

## Why use OS keychain

AI agents (including Claude Code) can read your shell history, environment variables, and config files. Tokens stored insecurely are routinely leaked. The OS keychain is encrypted at rest and requires user authorization to read.

## GitHub

### Recommended: GitHub CLI (OAuth)

```bash
gh auth login
# Follow prompts:
#   - Account: github.com (or your GitHub Enterprise)
#   - Protocol: HTTPS or SSH
#   - Auth method: Login with web browser (OAuth)
#
# Token is stored in:
#   macOS:   Keychain
#   Windows: Credential Manager
#   Linux:   ~/.config/gh/hosts.yml (with OAuth flow)
```

Verify:

```bash
gh auth status
```

### Alternative 1: Fine-grained Personal Access Token

Use this if you can't install `gh`.

**1. Create token**: <https://github.com/settings/personal-access-tokens/new>

- Token name: `git-skill (your-machine)`
- Expiration: 30 / 90 / 366 days
- Resource owner: yourself
- Repository access: All repositories (or specific)
- **Permissions** (minimum required):
  - Repository: Contents (Read/Write), Issues (Read/Write), Pull requests (Read/Write), Metadata (Read-only, auto)
  - Account: optional

**2. Store in OS keychain**:

macOS:
```bash
security add-generic-password -a github -s ghtoken -w "<your-PAT>"
# Verify: security find-generic-password -a github -s ghtoken -w
```

Windows (PowerShell):
```powershell
# Use Credential Manager via cmdkey
cmdkey /generic:github /user:<your-PAT>
```

Linux:
```bash
# Using libsecret (gnome-keyring, KWallet)
secret-tool store --label="GitHub PAT" service ghtoken
# When prompted: account=anyuser, password=<your-PAT>
```

**3. Tell git-skill to use it**:

The skill will read from env var `GH_TOKEN`. To make it automatic from keychain, add to `~/.zshrc` or `~/.bashrc`:

```bash
export GH_TOKEN="$(security find-generic-password -a github -s ghtoken -w 2>/dev/null)"
# Linux:
export GH_TOKEN="$(secret-tool lookup service ghtoken 2>/dev/null)"
```

Or simply:

```bash
export GH_TOKEN="<paste here>"
# Don't add this to .zshrc — paste once per session
```

### Alternative 2: SSH key

```bash
# Generate (if you don't have one)
ssh-keygen -t ed25519 -C "you@example.com"
# Public key prints below; add to https://github.com/settings/keys

# Test
ssh -T git@github.com
# Should print: Hi <username>! You've successfully authenticated...
```

git-skill will detect SSH access via remote URL and use SSH protocol.

## Gitee

### Recommended: oschina/gitee-cli

```bash
# Install (see https://gitee.com/oschina/gitee-cli for current method)
# Then:
gitee auth login
# Token stored in OS keychain
```

Verify:
```bash
gitee auth status
```

### Alternative 1: Personal Access Token

**1. Create token**: <https://gitee.com/personal_access_tokens>

Minimum scopes:

- `user_info` — basic profile
- `projects` — repo create/read/write
- `pull_requests` — PR operations
- `issues` — issue operations

**2. Store in OS keychain**:

macOS:
```bash
security add-generic-password -a gitee -s giteetoken -w "<your-token>"
```

Windows:
```powershell
cmdkey /generic:gitee /user:<your-token>
```

Linux:
```bash
secret-tool store --label="Gitee Token" service giteetoken
```

**3. Use**:

```bash
export GITEE_TOKEN="<paste here>"
# Or in ~/.zshrc:
export GITEE_TOKEN="$(security find-generic-password -a gitee -s giteetoken -w 2>/dev/null)"
```

### Alternative 2: SSH key

```bash
ssh-keygen -t ed25519 -C "you@example.com"
# Add public key at https://gitee.com/profile/sshkeys

ssh -T git@gitee.com
# Should print: Hi <username>! You've successfully authenticated...
```

## ❌ NEVER DO THIS

```bash
# 1. Don't add token to ~/.zshrc / ~/.bashrc (visible to AI agents)
echo 'export GH_TOKEN=ghp_xxxxx' >> ~/.zshrc  # BAD

# 2. Don't pass token inline (goes to shell history)
/git push --token ghp_xxxxx  # BAD

# 3. Don't commit token to repo (permanent leak)
# In any file, in commit message, in PR description  # BAD

# 4. Don't log token in scripts
echo "Token: $GH_TOKEN"  # BAD (if output is captured)

# 5. Don't put token in URL
git clone https://ghp_xxxxx@github.com/user/repo.git  # BAD (URLs are logged everywhere)
```

## Verification

```bash
/git auth                              # Auto-detect current platform
/git auth --platform github           # GitHub-specific check
/git auth --platform gitee --guide    # Show setup guide even if auth works
```

## Rotation

Best practice: rotate tokens every 90 days.

```bash
# 1. Create new token on the platform
# 2. Update keychain:
security delete-generic-password -a github -s ghtoken
security add-generic-password -a github -s ghtoken -w "<new-PAT>"

# 3. Verify
gh auth status  # or whatever method you use
```

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `gh: not authenticated` | `gh auth login` not run | `gh auth login` |
| `GH_TOKEN not set` | env var not exported | Add to shell rc or keychain |
| `Permission denied (publickey)` | SSH key not registered | Add to <https://github.com/settings/keys> |
| `Bad credentials` (REST API) | Token wrong / expired | Re-create, update keychain |
| `GITEE_TOKEN not set` | env var not exported | Same as GH_TOKEN fix |
| `fatal: Authentication failed` | Multiple issues | Run `/git auth --guide` |