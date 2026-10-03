#!/usr/bin/env pwsh
# hook-precommit.ps1 — PreToolUse hook template (Layer 1 protection)
#
# Install by adding to ~/.claude/settings.json:
#
# {
#   "hooks": {
#     "PreToolUse": [{
#       "matcher": "Bash",
#       "hooks": [{
#         "type": "command",
#         "command": "${USERPROFILE}\\.claude\\skills\\git\\scripts\\hook-precommit.ps1"
#       }]
#     }]
#   }
# }
#
# This catches `git commit` / `git push` even when not invoked through the skill.

$ErrorActionPreference = 'Continue'

# Read hook input from stdin (Claude Code passes tool invocation JSON)
$inputJson = [Console]::In.ReadToEnd()
if (-not $inputJson) { exit 0 }

try {
    $hookData = $inputJson | ConvertFrom-Json -ErrorAction Stop
} catch {
    exit 0
}

$toolInput = $hookData.tool_input
if (-not $toolInput) { exit 0 }

$command = $toolInput.command
if (-not $command) { exit 0 }

# Only intercept git commit / git push
if ($command -notmatch '^\s*git\s+(commit|push)\b') { exit 0 }

# Skip if --no-verify
if ($command -match '--no-verify') { exit 0 }

# Locate the skill's check-secrets script
$skillDir = if ($env:CLAUDE_SKILL_DIR) { $env:CLAUDE_SKILL_DIR }
            elseif ($env:USERPROFILE) { Join-Path $env:USERPROFILE '.claude\skills\git' }
            else { $null }

if (-not $skillDir -or -not (Test-Path $skillDir)) { exit 0 }

$checkScript = Join-Path $skillDir 'scripts\check-secrets.ps1'
if (-not (Test-Path $checkScript)) { exit 0 }

Write-Host "[hook] PreToolUse: intercepting git commit/push for secret scan..." -ForegroundColor Cyan

& pwsh $checkScript --severity critical,high
$exitCode = $LASTEXITCODE

if ($exitCode -eq 2) {
    Write-Host ""
    Write-Host "[hook] ✗ BLOCKED: CRITICAL secret detected" -ForegroundColor Red
    Write-Host "[hook]   Cannot bypass via hook. Edit the file, rotate the secret, add to .gitignore." -ForegroundColor Red
    exit 2
}

if ($exitCode -eq 3) {
    Write-Host ""
    Write-Host "[hook] ⚠ HIGH severity findings. Bypass requires explicit user confirmation in skill flow." -ForegroundColor Yellow
    exit 2
}

exit 0