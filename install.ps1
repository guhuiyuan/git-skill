<#
.SYNOPSIS
    Deploy git-skill to ~/.claude/skills/git/ on Windows.

.DESCRIPTION
    PowerShell 5+ install script. Runs on Windows native (PowerShell.exe)
    and PowerShell Core (pwsh).

.EXAMPLE
    .\install.ps1
    SKILL_HOME=$env:USERPROFILE\.claude\skills\git-test .\install.ps1
#>

[CmdletBinding()]
param(
    [string]$SkillHome = "$env:USERPROFILE\.claude\skills\git"
)

$ErrorActionPreference = 'Stop'

# ----- Resolve paths -----
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SrcDir    = Join-Path $ScriptDir "skills\git"
$SkillHome = $SkillHome

Write-Host ""
Write-Host "[git-skill] Git Skill installer v1.0.0" -ForegroundColor Cyan
Write-Host "[git-skill] Source: $SrcDir"
Write-Host "[git-skill] Target: $SkillHome"
Write-Host ""

# ----- Pre-flight -----
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[error] git is required but not installed." -ForegroundColor Red
    exit 1
}
Write-Host "[ok] git: $(git --version)" -ForegroundColor Green

if (-not (Test-Path $SrcDir)) {
    Write-Host "[error] Source skill directory not found: $SrcDir" -ForegroundColor Red
    Write-Host "[error] Are you running this from the git-skill repository root?" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path (Join-Path $SrcDir "SKILL.md"))) {
    Write-Host "[error] SKILL.md not found in $SrcDir. Corrupted source?" -ForegroundColor Red
    exit 1
}

# ----- Existing install -----
if (Test-Path $SkillHome) {
    Write-Host "[warn] An installation already exists at $SkillHome" -ForegroundColor Yellow
    $choice = Read-Host "Choose: [u]pgrade / [r]einstall / [c]ancel"
    switch ($choice.ToLower()) {
        'u' { Write-Host "[git-skill] Upgrading in place..." }
        'r' {
            $backup = "$SkillHome.bak.$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
            Move-Item $SkillHome $backup -Force
            Write-Host "[ok] Backed up existing install to $backup" -ForegroundColor Green
        }
        default {
            Write-Host "[error] Cancelled by user" -ForegroundColor Red
            exit 0
        }
    }
}

# ----- Copy -----
New-Item -ItemType Directory -Force -Path $SkillHome | Out-Null
Copy-Item -Path "$SrcDir\*" -Destination $SkillHome -Recurse -Force
Write-Host "[ok] Copied skill to $SkillHome" -ForegroundColor Green

# ----- Dependency check -----
$depsScript = Join-Path $SkillHome "scripts\install-deps.ps1"
if (Test-Path $depsScript) {
    Write-Host ""
    Write-Host "[git-skill] Checking dependencies..." -ForegroundColor Cyan
    try {
        & $depsScript
    } catch {
        Write-Host "[warn] Dependency check failed: $_" -ForegroundColor Yellow
    }
}

# ----- Done -----
Write-Host ""
Write-Host "[ok] Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Restart Claude Code (or run /reload-skills if available)"
Write-Host "  2. Try:  /git help"
Write-Host "  3. Auth (one-time):"
Write-Host "       - Recommended: gh auth login (GitHub) / gitee auth login (Gitee)"
Write-Host "       - Or set GH_TOKEN / GITEE_TOKEN env vars"
Write-Host "       - Or configure ~/.ssh\id_* and add to your platform"
Write-Host ""
Write-Host "Uninstall: $(Join-Path $ScriptDir 'uninstall.ps1')"
Write-Host ""