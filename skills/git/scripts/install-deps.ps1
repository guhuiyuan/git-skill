<#
.SYNOPSIS
    install-deps.ps1 - Check and recommend installation of git-skill dependencies.

.DESCRIPTION
    Required: git
    Recommended: gitleaks, gh, gitee-cli (with fallbacks)
    Optional: curl, ssh

.PARAMETER Install
    Try to install missing recommended tools via available package manager.
#>

[CmdletBinding()]
param(
    [switch]$Install
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "_lib\common.ps1")

# ----- Detect package manager -----
function Get-PackageManager {
    if (Test-HasCmd "winget")  { return "winget" }
    if (Test-HasCmd "scoop")   { return "scoop" }
    if (Test-HasCmd "choco")   { return "choco" }
    if (Test-HasCmd "brew")    { return "brew" }
    return "none"
}

$PackageManager = Get-PackageManager

# ----- Check function -----
function Test-Tool {
    param(
        [string]$Name,
        [ValidateSet("mandatory","recommended","optional")] [string]$Required,
        [string]$InstallHint
    )
    if (Test-HasCmd $Name) {
        $version = switch ($Name) {
            "git"      { & git --version 2>$null }
            "gitleaks" { & gitleaks version 2>$null }
            "gh"       { (& gh --version 2>$null) | Select-Object -First 1 }
            "gitee"    { (& gitee --version 2>$null) | Select-Object -First 1 }
            default    { "installed" }
        }
        Write-Host "[ok] $Name: $version" -ForegroundColor Green
        return $true
    }

    if ($Required -eq "mandatory") {
        Write-Host "[err] $Name is required but not installed. $InstallHint" -ForegroundColor Red
        return $false
    }
    Write-Host "[warn] $Name: not installed ($Required). $InstallHint" -ForegroundColor Yellow
    return $false
}

# ----- Main -----
Write-Host "[info] Checking git-skill dependencies..."
Write-Host ""

$missingRecommended = @()

# Mandatory
if (-not (Test-Tool -Name "git" -Required "mandatory" -InstallHint "Install from https://git-scm.com/")) {
    exit 1
}

# Recommended
if (-not (Test-Tool -Name "gitleaks" -Required "recommended" `
    -InstallHint "Install: scoop install gitleaks / winget install gitleaks / https://github.com/gitleaks/gitleaks/releases")) {
    $missingRecommended += "gitleaks"
}

if (-not (Test-Tool -Name "gh" -Required "recommended" `
    -InstallHint "Install: scoop install gh / winget install GitHub.cli / https://cli.github.com/")) {
    $missingRecommended += "gh"
}

if (-not (Test-Tool -Name "gitee" -Required "recommended" `
    -InstallHint "Install from https://gitee.com/oschina/gitee-cli")) {
    $missingRecommended += "gitee"
}

# Optional
[void](Test-Tool -Name "curl" -Required "optional" -InstallHint "any package manager")
[void](Test-Tool -Name "ssh"  -Required "optional" -InstallHint "any package manager")

Write-Host ""

if ($missingRecommended.Count -eq 0) {
    Write-Host "[ok] All recommended tools are installed. You're all set!" -ForegroundColor Green
} else {
    Write-Host "[warn] Missing recommended tools: $($missingRecommended -join ', ')" -ForegroundColor Yellow
    Write-Host "[info] The skill will work with reduced functionality. See above for install hints." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "[info] Auth setup: run '/git auth' for guided configuration (OS keychain recommended)." -ForegroundColor Cyan
exit 0