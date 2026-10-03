<#
.SYNOPSIS
    detect-state.ps1 - Inspect current working directory git state.
#>

[CmdletBinding()]
param(
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "_lib\common.ps1")

$isRepo    = $false
$branch    = ""
$defaultBranch = ""
$remoteUrl = ""
$platform  = "unknown"
$authMethod = "none"
$dirty     = $false

if (git rev-parse --is-inside-work-tree 2>$null) {
    $isRepo = $true
    try { $branch = (git symbolic-ref --short HEAD 2>$null) } catch { $branch = (git rev-parse --short HEAD 2>$null) }
    try {
        $remoteInfo = (git remote show origin 2>$null) | Select-String "HEAD branch:"
        if ($remoteInfo) { $defaultBranch = ($remoteInfo -split "HEAD branch:")[1].Trim() }
    } catch { }
    if (-not $defaultBranch) { $defaultBranch = (git config --get init.defaultBranch 2>$null); if (-not $defaultBranch) { $defaultBranch = "main" } }
    $remoteUrl = (git remote get-url origin 2>$null)

    if ($remoteUrl -match "github\.com|githubusercontent|ghe\.com") {
        $platform = "github"
    } elseif ($remoteUrl -match "gitee\.com") {
        $platform = "gitee"
    }

    if ($platform -eq "github") {
        if (Test-HasCmd "gh") {
            try { $null = & gh auth status 2>&1; if ($LASTEXITCODE -eq 0) { $authMethod = "gh" } } catch {}
        }
        if ($authMethod -eq "none" -and $env:GH_TOKEN) { $authMethod = "token" }
        if ($authMethod -eq "none" -and $remoteUrl -like "git@*") { $authMethod = "ssh" }
    } elseif ($platform -eq "gitee") {
        if (Test-HasCmd "gitee") {
            try { $null = & gitee auth status 2>&1; if ($LASTEXITCODE -eq 0) { $authMethod = "gitee" } } catch {}
        }
        if ($authMethod -eq "none" -and $env:GITEE_TOKEN) { $authMethod = "token" }
        if ($authMethod -eq "none" -and $remoteUrl -like "git@*") { $authMethod = "ssh" }
    }

    $diffResult = (git diff 2>$null)
    $diffCachedResult = (git diff --cached 2>$null)
    if ($diffResult -or $diffCachedResult) { $dirty = $true }
}

if ($Json) {
    $obj = @{
        is_repo        = $isRepo
        branch         = $branch
        default_branch = $defaultBranch
        remote         = $remoteUrl
        platform       = $platform
        auth           = $authMethod
        dirty          = $dirty
    }
    $obj | ConvertTo-Json -Compress
} else {
    Write-Host "Git repo: $isRepo"
    Write-Host "Branch: $($branch ?? '<none>')"
    Write-Host "Default branch: $($defaultBranch ?? '<unknown>')"
    Write-Host "Remote origin: $($remoteUrl ?? '<none>')"
    Write-Host "Platform: $platform"
    Write-Host "Auth method: $authMethod"
    Write-Host "Uncommitted changes: $dirty"
}

exit 0