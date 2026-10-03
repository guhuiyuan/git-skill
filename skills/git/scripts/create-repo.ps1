#!/usr/bin/env pwsh
# create-repo.ps1 — Create a new remote repo on GitHub or Gitee

param(
    [Parameter(Mandatory)] [string]$Name,
    [ValidateSet('github','gitee')] [string]$Platform = 'github',
    [switch]$Public = $false,
    [switch]$Private = $false,
    [string]$Description = '',
    [string]$Org = '',
    [switch]$Help = $false
)

if ($Help) {
    @"
create-repo — Create a remote repository

USAGE:
    pwsh create-repo.ps1 -Name my-app -Platform github [-Public] [-Private] [-Description '...'] [-Org my-org]
"@
    exit 0
}

$ErrorActionPreference = 'Stop'

# Default visibility
if (-not $Public -and -not $Private) {
    $Public = $true   # default to public
}

$platformDir = Join-Path $PSScriptRoot '_platform'
. (Join-Path $platformDir "$Platform.ps1")

$fn = "${Platform}_repo_create"
& $fn -Name $Name -Private:$Private -Public:$Public -Description $Description -Org $Org

exit $LASTEXITCODE