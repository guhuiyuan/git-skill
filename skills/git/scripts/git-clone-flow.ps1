#!/usr/bin/env pwsh
# git-clone-flow.ps1 — Clone with platform auto-detection

param(
    [Parameter(Mandatory)] [string]$Url,
    [string]$Directory = '',
    [int]$Depth = 0,
    [switch]$Help = $false
)

if ($Help) {
    @"
git-clone-flow — Clone a repository with platform detection

USAGE:
    pwsh git-clone-flow.ps1 <url> [-Directory <Path>] [-Depth N]
"@
    exit 0
}

$ErrorActionPreference = 'Stop'

# Detect platform
$platform = 'unknown'
if ($Url -match 'github\.com') { $platform = 'github' }
elseif ($Url -match 'gitee\.com') { $platform = 'gitee' }

Write-Host "Detected platform: $platform" -ForegroundColor Cyan

$args = @('clone', $Url)
if ($Directory) { $args += $Directory }
if ($Depth -gt 0) { $args += @('--depth', $Depth.ToString()) }

git @args
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host "✓ Cloned successfully" -ForegroundColor Green
    if ($Directory -and (Test-Path $Directory)) {
        Write-Host ""
        Write-Host "Next:"
        Write-Host "  cd $Directory"
        Write-Host "  /git auth --platform $platform     # verify auth"
        Write-Host "  /git status"
    }
}

exit $exitCode