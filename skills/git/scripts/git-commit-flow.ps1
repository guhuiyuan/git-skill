#!/usr/bin/env pwsh
# git-commit-flow.ps1 — Commit with mandatory secret scan
# Usage: pwsh git-commit-flow.ps1 -m "msg" [--amend] [--force-allow-high]

param(
    [string]$Message = '',
    [switch]$Amend = $false,
    [switch]$ForceAllowHigh = $false,
    [switch]$NoVerify = $false,
    [switch]$All = $false,
    [switch]$Help = $false
)

if ($Help) {
    @"
git-commit-flow — Stage and commit with secret scanning

USAGE:
    pwsh git-commit-flow.ps1 -m "feat: add login"
    pwsh git-commit-flow.ps1 --amend
    pwsh git-commit-flow.ps1 -m "..." -ForceAllowHigh

OPTIONS:
    -m <message>              Commit message (required unless --amend)
    --amend                   Amend previous commit
    --all, -A                 Stage all changes first
    --force-allow-high        Bypass HIGH severity secret warnings
    --no-verify               Skip pre-commit hooks
    --help, -h                Show this help

EXIT CODES:
    0   success
    1   general failure
    2   blocked by CRITICAL secret
    3   user cancelled
"@
    exit 0
}

$ErrorActionPreference = 'Stop'

$libDir = Join-Path $PSScriptRoot '_lib'
. (Join-Path $libDir 'common.ps1')

if (-not (Test-Path '.git')) {
    Write-Error "Not a git repository. Run 'git-init-flow' first."
    exit 1
}

# Stage if requested
if ($All) {
    git add -A 2>&1 | Out-Null
}

# Check if there's anything to commit
$status = git status --porcelain
if (-not $status -and -not $Amend) {
    Write-Host "Nothing to commit, working tree clean" -ForegroundColor Yellow
    exit 0
}

# Validate message
if (-not $Message -and -not $Amend) {
    Write-Error "Commit message required (-m). Use --amend to modify last commit."
    exit 1
}

# Run secret scan BEFORE commit
Write-Host "Scanning staged changes for secrets..." -ForegroundColor Cyan
$scanArgs = @('--severity', 'critical,high')
if ($ForceAllowHigh) { $scanArgs += '--force-allow-high' }

& (Join-Path $PSScriptRoot 'check-secrets.ps1') @scanArgs
$scanExit = $LASTEXITCODE

if ($scanExit -eq 2) {
    Write-Host ""
    Write-Host "✗ Commit blocked by CRITICAL secret" -ForegroundColor Red
    Write-Host "  Remove the secret from the file, rotate it on the platform, and add the file to .gitignore."
    Write-Host "  See references/secret-patterns.md for details."
    exit 2
}

if ($scanExit -eq 3) {
    Write-Warning "HIGH severity findings. Use --force-allow-high to bypass if confirmed false positive."
    exit 1
}

# Build commit command
$args = @('commit')
if ($Amend) { $args += '--amend' }
if ($NoVerify) { $args += '--no-verify' }
if ($Message) { $args += @('-m', $Message) }

git @args
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host ""
    Write-Host "✓ Commit successful" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next:"
    Write-Host "  /git push                # push to remote"
    Write-Host "  /git pr new -m '...'      # create PR (after push)"
}
exit $exitCode