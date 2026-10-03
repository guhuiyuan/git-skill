<#
.SYNOPSIS
    auth-detect.ps1 - Detect and guide authentication setup for GitHub / Gitee.
#>

[CmdletBinding()]
param(
    [ValidateSet('github','gitee','')] [string]$Platform = '',
    [switch]$Guide,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "_lib\common.ps1")

if (-not $Platform) {
    $Platform = (& (Join-Path $ScriptDir "platform-detect.ps1"))
}

# ----- GitHub -----
function Test-GitHubAuth {
    $method = "none"
    if (Test-HasCmd "gh") {
        try { $null = & gh auth status 2>&1; if ($LASTEXITCODE -eq 0) { $method = "gh-cli" } } catch {}
    }
    if ($method -eq "none" -and $env:GH_TOKEN) { $method = "token" }
    if ($method -eq "none" -and ((Test-Path "$env:USERPROFILE\.ssh\id_ed25519") -or (Test-Path "$env:USERPROFILE\.ssh\id_rsa"))) {
        try {
            $result = & ssh -T -o BatchMode=yes -o ConnectTimeout=5 git@github.com 2>&1
            if ($result -match "successfully authenticated") { $method = "ssh" }
        } catch {}
    }

    if ($Json) {
        @{
            platform = "github"
            method   = $method
        } | ConvertTo-Json -Compress
    } else {
        Write-Host "GitHub auth: $method"
        if ($method -eq "none" -or $Guide) {
            Write-Host ""
            Write-Host "GitHub authentication setup" -ForegroundColor Cyan
            Write-Host "============================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Recommended: GitHub CLI (OAuth, secure)"
            Write-Host "  gh auth login"
            Write-Host ""
            Write-Host "Alternative 1: Fine-grained PAT (in env var)"
            Write-Host "  1. Create PAT at https://github.com/settings/tokens?type=beta"
            Write-Host "  2. Use Windows Credential Manager:"
            Write-Host "     cmdkey /generic:github /user:<your-PAT>"
            Write-Host ""
            Write-Host "Alternative 2: SSH key"
            Write-Host "  1. ssh-keygen -t ed25519 -C 'you@example.com'"
            Write-Host "  2. Add to GitHub: https://github.com/settings/keys"
            Write-Host ""
            Write-Host "NEVER:"
            Write-Host "  - Inline /git push --token xxx (shell history)"
            Write-Host "  - Commit token to repo (permanent leak)"
        }
    }
}

# ----- Gitee -----
function Test-GiteeAuth {
    $method = "none"
    if (Test-HasCmd "gitee") {
        try { $null = & gitee auth status 2>&1; if ($LASTEXITCODE -eq 0) { $method = "gitee-cli" } } catch {}
    }
    if ($method -eq "none" -and $env:GITEE_TOKEN) { $method = "token" }
    if ($method -eq "none" -and ((Test-Path "$env:USERPROFILE\.ssh\id_ed25519") -or (Test-Path "$env:USERPROFILE\.ssh\id_rsa"))) {
        try {
            $result = & ssh -T -o BatchMode=yes -o ConnectTimeout=5 git@gitee.com 2>&1
            if ($result -match "successfully authenticated|Welcome to Gitee") { $method = "ssh" }
        } catch {}
    }

    if ($Json) {
        @{
            platform = "gitee"
            method   = $method
        } | ConvertTo-Json -Compress
    } else {
        Write-Host "Gitee auth: $method"
        if ($method -eq "none" -or $Guide) {
            Write-Host ""
            Write-Host "Gitee authentication setup" -ForegroundColor Cyan
            Write-Host "============================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Recommended: oschina/gitee-cli"
            Write-Host "  Install: https://gitee.com/oschina/gitee-cli"
            Write-Host "  Then:    gitee auth login"
            Write-Host ""
            Write-Host "Alternative 1: Personal Access Token"
            Write-Host "  1. Create at https://gitee.com/personal_access_tokens"
            Write-Host "  2. Use Windows Credential Manager:"
            Write-Host "     cmdkey /generic:gitee /user:<your-PAT>"
            Write-Host ""
            Write-Host "NEVER:"
            Write-Host "  - Inline /git push --token xxx"
            Write-Host "  - Commit token to repo"
        }
    }
}

switch ($Platform) {
    'github' { Test-GitHubAuth }
    'gitee'  { Test-GiteeAuth  }
    default  {
        Write-Host "[warn] Cannot detect platform: no remote configured" -ForegroundColor Yellow
        Test-GitHubAuth
        Write-Host ""
        Test-GiteeAuth
    }
}