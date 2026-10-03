# Platform Compatibility — Windows / macOS / Linux

This skill supports all major platforms via dual-script strategy (`.sh` + `.ps1`).

## Shell compatibility

| OS | Shell | Script extension | Notes |
|---|---|---|---|
| macOS | bash 3.2+ / zsh | `.sh` | All scripts work natively |
| Linux | bash 4+ | `.sh` | Tested on Ubuntu, Debian, Fedora, Arch |
| Windows — Git Bash | bash 4+ | `.sh` | Provided by Git for Windows |
| Windows — PowerShell | pwsh 5+ / 7+ | `.ps1` | Native execution |
| Windows — CMD | cmd.exe | `.cmd` | Only for install/uninstall |

## Path conventions

| OS | Path separator | Example home |
|---|---|---|
| macOS / Linux | `/` | `/Users/me/.claude/skills/git/` |
| Windows | `\` | `C:\Users\me\.claude\skills\git\` |

Skill resolves `${HOME}` (POSIX) and `$env:USERPROFILE` (Windows) correctly.

## Line endings

- `.sh` scripts: LF only (`\n`)
- `.ps1` scripts: LF or CRLF (PowerShell handles both)
- Templates: LF only (best for cross-platform)

If you see `\r` issues on Windows, run:

```bash
dos2unix skills/git/scripts/*.sh   # Linux
# Or:
sed -i 's/\r$//' file.sh           # Linux/macOS
```

## Common cross-platform issues

### 1. Symlinks (Windows)

Windows requires admin or developer mode for `symlink`. The install script does NOT create symlinks to avoid permission issues — it always copies. Use `git pull` to upgrade.

### 2. `chmod +x` on Windows

Git Bash on Windows: `chmod +x file.sh` works in Git Bash but the host filesystem may not preserve the +x bit if files are committed/pulled via NTFS. Skill handles this by always re-applying `chmod +x` in `install.sh`.

### 3. Line endings in `.gitattributes`

Add to `.gitattributes` of any repo using this skill:

```
*.sh text eol=lf
*.ps1 text eol=lf
*.md text eol=lf
```

### 4. `which` vs `command -v`

POSIX: `command -v <cmd>` (preferred)
Windows: `Get-Command <cmd>`

Skill uses platform-specific detection.

### 5. ANSI colors

- macOS Terminal: ✅ ANSI
- Linux: ✅ ANSI (most terminals)
- Windows CMD: ❌ (no ANSI by default)
- Windows PowerShell: ✅ (5+ supports ANSI)
- Git Bash on Windows: ✅

Skill auto-detects TTY and `NO_COLOR=1` env var.

### 6. Path expansion

- POSIX: `~` expands to `$HOME`
- Windows: `~` does NOT expand in cmd.exe; use `%USERPROFILE%`

Skill uses `${HOME}` / `$env:USERPROFILE` explicitly to avoid issues.

### 7. Process spawning

- POSIX: `&` for background, `$()` for command substitution
- PowerShell: `Start-Process`, `$(...)` works similarly

Skill shells out to `git`, `gh`, `gitee`, `gitleaks`, `curl` natively on each platform.

## Tested matrix

| Platform | Shell | Status |
|---|---|---|
| macOS 14 Sonoma | bash 5.2 | ✅ Verified |
| macOS 13 Ventura | zsh 5.9 | ✅ Verified |
| Ubuntu 24.04 LTS | bash 5.2 | ✅ Verified |
| Fedora 40 | bash 5.2 | ✅ Verified |
| Debian 12 | bash 5.2 | ✅ Verified |
| Arch Linux | bash 5.2 | ✅ Verified |
| Windows 11 + Git Bash | bash 4.4 | ✅ Verified |
| Windows 11 + PowerShell 7 | pwsh 7.4 | ✅ Verified |
| Windows 11 + PowerShell 5.1 | ps5.1 | ✅ Verified |
| Windows 11 + CMD | cmd.exe | ✅ Verified (install only) |

## Reporting platform-specific issues

If you encounter a platform-specific bug:

1. Open an issue: <https://github.com/<owner>/git-skill/issues>
2. Include:
   - OS + version (`uname -a` or `winver`)
   - Shell + version (`bash --version` or `$PSVersionTable`)
   - Output of `install.sh --verbose` or `install.ps1 -Verbose`
   - Full error message + stack trace