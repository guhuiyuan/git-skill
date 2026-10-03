<#
.SYNOPSIS
    Remove git-skill from ~/.claude/skills/git/.
#>

[CmdletBinding()]
param(
    [string]$SkillHome = "$env:USERPROFILE\.claude\skills\git"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $SkillHome)) {
    Write-Host "[git-skill] No installation found at $SkillHome"
    exit 0
}

Write-Host "[git-skill] Will remove: $SkillHome"
$confirm = Read-Host "Are you sure? [y/N]"
if ($confirm -notin @('y','Y','yes','YES')) {
    Write-Host "[git-skill] Cancelled"
    exit 0
}

Remove-Item -Path $SkillHome -Recurse -Force
Write-Host "[ok] Removed $SkillHome"
Write-Host ""
Write-Host "Restart Claude Code to pick up changes."