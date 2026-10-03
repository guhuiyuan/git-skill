#!/usr/bin/env pwsh
# precommit-guard.ps1 — Git pre-commit hook (when core.hooksPath is set to skill)
#
# Usage:
#   git config core.hooksPath ~/.claude/skills/git/scripts
#   # Now `git commit` automatically runs this guard before secrets go in

$ErrorActionPreference = 'Continue'

# Determine skill location
$skillDir = $PSScriptRoot
$checkScript = Join-Path $skillDir 'check-secrets.ps1'

if (-not (Test-Path $checkScript)) {
    Write-Warning "[precommit-guard] check-secrets.ps1 not found, skipping scan"
    exit 0
}

Write-Host "[precommit-guard] Scanning staged changes..." -ForegroundColor Cyan
& pwsh $checkScript --severity critical,high --staged
$exitCode = $LASTEXITCODE

if ($exitCode -eq 2) {
    Write-Host ""
    Write-Host "[precommit-guard] ✗ CRITICAL secret found. Commit aborted." -ForegroundColor Red
    Write-Host "[precommit-guard]   1. Remove the secret from the file" -ForegroundColor Red
    Write-Host "[precommit-guard]   2. Rotate it on the platform" -ForegroundColor Red
    Write-Host "[precommit-guard]   3. Add the file to .gitignore" -ForegroundColor Red
    exit 1
}

if ($exitCode -eq 3) {
    Write-Host ""
    Write-Host "[precommit-guard] ⚠ HIGH severity finding(s). Bypass with --no-verify (NOT recommended)" -ForegroundColor Yellow
    exit 1
}

exit 0