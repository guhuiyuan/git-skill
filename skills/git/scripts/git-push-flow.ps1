#!/usr/bin/env pwsh
# git-push-flow.ps1 — Push with secret scan + safety checks
# Usage: pwsh git-push-flow.ps1 [--remote origin] [--branch main] [--force-with-lease]

param(
    [string]$Remote = 'origin',
    [string]$Branch = '',
    [switch]$Force = $false,
    [switch]$ForceWithLease = $false,
    [switch]$SetUpstream = $false,
    [switch]$All = $false,
    [switch]$Tags = $false,
    [switch]$DryRun = $false,
    [switch]$Help = $false
)

if ($Help) {
    @"
git-push-flow — Push to remote with secret scan and safety checks

USAGE:
    pwsh git-push-flow.ps1 [-Remote origin] [-Branch <current>]
    pwsh git-push-flow.ps1 -SetUpstream    # first push
    pwsh git-push-flow.ps1 --force-with-lease

OPTIONS:
    -Remote <name>            Remote name (default: origin)
    -Branch <name>            Branch (default: current)
    -SetUpstream, -u          Set upstream tracking
    --all                     Push all branches
    --tags                    Push all tags
    --force                   Force push (will prompt for confirmation)
    --force-with-lease        Safer force push (recommended)
    --dry-run                 Show what would be pushed
    --help, -h                Show this help

SAFETY:
    - Secret scan runs again before push (defense in depth)
    - main / master force push is always blocked
    - --force requires interactive confirmation
"@
    exit 0
}

$ErrorActionPreference = 'Stop'

$libDir = Join-Path $PSScriptRoot '_lib'
. (Join-Path $libDir 'common.ps1')

if (-not (Test-Path '.git')) {
    Write-Error "Not a git repository."
    exit 1
}

# Detect current branch
if (-not $Branch) {
    $Branch = git branch --show-current
    if (-not $Branch) {
        Write-Error "Not on any branch (detached HEAD?). Use -Branch to specify."
        exit 1
    }
}

# Detect remote URL / platform
$remoteUrl = git remote get-url $Remote 2>$null
if (-not $remoteUrl) {
    Write-Error "Remote '$Remote' not found. Run 'git-remote-flow' to add one."
    exit 1
}

$platform = if ($remoteUrl -match 'github') { 'github' }
            elseif ($remoteUrl -match 'gitee')  { 'gitee'  }
            else                                 { 'unknown' }

Write-Host "Pushing to $Remote/$Branch ($platform)..." -ForegroundColor Cyan

# Safety: force on main / master
if (($Force -or $ForceWithLease) -and $Branch -in @('main','master')) {
    Write-Host ""
    Write-Host "✗ BLOCKED: Force push to $Branch is dangerous." -ForegroundColor Red
    Write-Host "  This would overwrite remote history and break teammates."
    exit 1
}

# Confirmation for --force
if ($Force) {
    Write-Host ""
    Write-Warning "You are about to FORCE PUSH to $Remote/$Branch."
    Write-Warning "This will overwrite remote history."
    $ans = Read-Host "Type 'force' to confirm"
    if ($ans -ne 'force') {
        Write-Host "Aborted."
        exit 3
    }
}

# Re-scan secrets before push (defense in depth)
Write-Host "Re-scanning for secrets..." -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'check-secrets.ps1') --severity critical
if ($LASTEXITCODE -eq 2) {
    Write-Host ""
    Write-Host "✗ Push blocked by CRITICAL secret" -ForegroundColor Red
    exit 2
}

# Build push args
$args = @('push', $Remote)
if ($SetUpstream) { $args += '-u' }
if ($All) { $args += '--all' }
if ($Tags) { $args += '--tags' }
if ($Force) { $args += '--force' }
elseif ($ForceWithLease) { $args += '--force-with-lease' }
if ($DryRun) { $args += '--dry-run' }

if (-not ($All -or $Tags)) {
    $args += $Branch
}

git @args
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host ""
    Write-Host "✓ Push successful" -ForegroundColor Green

    # Suggest next steps
    Write-Host ""
    Write-Host "Next:"
    if ($platform -eq 'github') {
        Write-Host "  /git pr new -m '...'                # create PR"
    } elseif ($platform -eq 'gitee') {
        Write-Host "  /git pr new -m '...' --base master  # create PR"
    }
    Write-Host "  /git status                         # see other uncommitted"
}
exit $exitCode