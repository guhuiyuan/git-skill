# Troubleshooting

Common errors and fixes.

## 1. `Permission denied (publickey)`

**Cause**: SSH key not registered on GitHub/Gitee.

**Fix**:

```bash
# Generate key if you don't have one
ssh-keygen -t ed25519 -C "you@example.com"

# Display public key
cat ~/.ssh/id_ed25519.pub    # macOS/Linux
type %USERPROFILE%\.ssh\id_ed25519.pub    # Windows

# Add to GitHub: https://github.com/settings/keys
# Add to Gitee:  https://gitee.com/profile/sshkeys

# Test
ssh -T git@github.com    # Should print "Hi <user>!"
ssh -T git@gitee.com
```

## 2. `fatal: not a git repository`

**Cause**: Current directory is not a git repository.

**Fix**:

```bash
# Either initialize
/git init

# Or clone from remote
/git clone https://github.com/user/repo.git

# Or cd into an existing repo
cd /path/to/existing/repo
```

## 3. `gitleaks: command not found`

**Cause**: gitleaks binary not installed. Skill is using embedded fallback rules (25% coverage).

**Fix** (recommended):

```bash
# macOS
brew install gitleaks

# Windows
scoop install gitleaks
# or
winget install gitleaks

# Linux (manual)
# Download from https://github.com/gitleaks/gitleaks/releases
sudo mv gitleaks /usr/local/bin/
```

After install, verify:

```bash
gitleaks version
/git scan  # Should report "[info] Using gitleaks (preferred)..."
```

## 4. `gh: not authenticated` (GitHub)

**Cause**: GitHub CLI not logged in.

**Fix**:

```bash
gh auth login
# Follow OAuth flow
gh auth status    # Verify
```

If you can't install `gh`, use Fine-grained PAT + keychain (see [auth-guide.md](auth-guide.md)).

## 5. `GITEE_TOKEN not set` (Gitee)

**Cause**: Environment variable not set, gitee CLI not installed.

**Fix** (option 1 — CLI):

```bash
# Install gitee CLI (see https://gitee.com/oschina/gitee-cli)
gitee auth login
```

**Fix** (option 2 — PAT):

```bash
# 1. Create token at https://gitee.com/personal_access_tokens
#    Required scopes: user_info, projects, pull_requests, issues
# 2. Store in keychain:
security add-generic-password -a gitee -s giteetoken -w "<token>"    # macOS
# 3. Export in current shell (DO NOT add to .zshrc):
export GITEE_TOKEN="$(security find-generic-password -a gitee -s giteetoken -w)"
```

## 6. `fatal: Authentication failed for ...`

**Cause**: Token expired / wrong / insufficient permissions.

**Fix**:

```bash
# Re-check auth
/git auth --platform github --guide

# For GitHub: regenerate at https://github.com/settings/personal-access-tokens
# For Gitee:  regenerate at https://gitee.com/personal_access_tokens
```

## 7. `git push` blocked by secret scanner

**Cause**: Skill detected CRITICAL secret in staged diff.

**Fix**:

```bash
# 1. See what was detected
/git scan --severity critical

# 2. Remove the secret from the file
# 3. Rotate the secret on the platform (CRITICAL = real secret, treat as compromised)
# 4. Add file to .gitignore
echo "secret-file.txt" >> .gitignore
git rm --cached secret-file.txt
/git commit -m "fix: remove leaked secret"

# Cannot bypass CRITICAL. HIGH can be bypassed:
/git commit --force-allow-high -m "..."
```

## 8. `fatal: refusing to merge unrelated histories`

**Cause**: Trying to merge repos with no common ancestor.

**Fix**:

```bash
git merge --allow-unrelated-histories <branch>
# Or for pull:
git pull --rebase --allow-unrelated-histories
```

## 9. Hook not triggering

**Cause**: PreToolUse hook not in `~/.claude/settings.json`, or wrong path.

**Fix**: verify settings:

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

Note: `${HOME}` works on macOS/Linux. On Windows, use `${USERPROFILE}\.claude\skills\git\scripts\hook-precommit.ps1` (note: .ps1 not .sh on Windows).

## 10. Skill not loading after install

**Fix**:

1. Verify install location: `ls ~/.claude/skills/git/SKILL.md`
2. Restart Claude Code (or run `/reload-skills` if available)
3. Try `/git help` — if SKILL.md loads, you're good
4. If not, check `~/.claude/settings.json` for permission denials

## 11. `git status` shows "detached HEAD"

**Cause**: Checked out a commit directly (not a branch).

**Fix**:

```bash
# Create branch from current state
git switch -c <new-branch-name>

# Or return to a known branch
git switch main
```

## 12. Merge conflicts

**Cause**: Two branches modified the same lines.

**Fix**:

```bash
# 1. See conflicted files
git status    # Files marked "Unmerged paths"

# 2. Open each file. Look for markers:
#    <<<<<<< HEAD
#    your changes
#    =======
#    their changes
#    >>>>>>> branch-name

# 3. Resolve by editing (delete markers, keep correct version)

# 4. Stage resolved file
git add <file>

# 5. Complete merge
git merge --continue
# Or for rebase:
git rebase --continue

# Abort at any time:
git merge --abort
git rebase --abort
```

## Getting more help

```bash
/git auth --guide              # Authentication setup wizard
/git scan                      # See secret scan results
./scripts/check-secrets.sh --help    # Full options
```

If unresolved: <https://github.com/<owner>/git-skill/issues>