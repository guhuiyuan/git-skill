#!/usr/bin/env pwsh
# git-merge-flow.ps1 — Merge / rebase branch

param(
    [Parameter(Mandatory)] [string]$Branch,
    [switch]$NoFF = $false,
    [switch]$Squash = $false,
    [switch]$Abort = $false,
    [switch]$Continue = $false,
    [switch]$Help = $false
)

if ($Help) {
    @"
git-merge-flow — Merge a branch into current

USAGE:
    pwsh git-merge-flow.ps1 <branch> [-NoFF] [-Squash]
    pwsh git-merge-flow.ps1 --abort
    pwsh git-merge-flow.ps1 --continue
"@
    exit 0
}

$ErrorActionPreference = 'Stop'

if ($Abort) {
    git merge --abort 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Merge aborted" -ForegroundColor Green
    } else {
        Write-Warning "No merge in progress"
    }
    exit 0
}

if ($Continue) {
    git merge --continue
    exit $LASTEXITCODE
}

# Run secret scan before merge
Write-Host "Pre-merge secret scan..." -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'check-secrets.ps1') --severity critical --working-tree
if ($LASTEXITCODE -eq 2) {
    Write-Host "✗ Merge blocked by CRITICAL secret" -ForegroundColor Red
    exit 2
}

$args = @('merge', $Branch)
if ($NoFF) { $args += '--no-ff' }
if ($Squash) { $args += '--squash' }

git @args
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host "✓ Merged $Branch into current branch" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next:"
    Write-Host "  /git push                 # push merge"
    Write-Host "  /git branch delete $Branch # cleanup (if no longer needed)"
} elseif ($exitCode -ne 0) {
    Write-Host ""
    Write-Host "✗ Merge has conflicts" -ForegroundColor Yellow
    Write-Host "  Resolve conflicts, then: git add <file> && /git merge-flow $Branch --continue"
    Write-Host "  Or abort with: /git merge-flow --abort"
}

exit $exitCode