<#
.SYNOPSIS
    platform-detect.ps1 - Determine whether current repo is GitHub, Gitee, or other.
#>

[CmdletBinding()]
param(
    [string]$Remote
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "_lib\common.ps1")

$remoteUrl = $Remote
if (-not $remoteUrl) {
    if (git rev-parse --is-inside-work-tree 2>$null) {
        $remoteUrl = (git remote get-url origin 2>$null)
    }
}

if (-not $remoteUrl) {
    Write-Output "no-remote"
    exit 0
}

switch -Regex ($remoteUrl) {
    'github\.com|githubusercontent|ghe\.com' { Write-Output "github"; exit 0 }
    'gitee\.com'                              { Write-Output "gitee"; exit 0 }
    default                                   { Write-Output "unknown"; exit 0 }
}