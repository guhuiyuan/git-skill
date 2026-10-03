#!/usr/bin/env pwsh
# git-pr-flow.ps1 — Pull Request management (GitHub + Gitee)

param(
    [Parameter(Mandatory)] [ValidateSet('list','new','view','merge','close')] [string]$Action,
    [string]$Title = '',
    [string]$Body = '',
    [string]$BodyFile = '',
    [string]$Base = '',
    [string]$Head = '',
    [switch]$Draft = $false,
    [ValidateSet('merge','squash','rebase')] [string]$MergeMethod = 'merge',
    [ValidateSet('open','closed','merged','all')] [string]$State = 'open',
    [int]$Limit = 30,
    [int]$Number = 0,
    [switch]$Help = $false
)

if ($Help) {
    @"
git-pr-flow — Pull Request management

USAGE:
    pwsh git-pr-flow.ps1 list [-State open] [-Limit 30]
    pwsh git-pr-flow.ps1 new -Title "..." -Base main [-Draft] [-Body "..."]
    pwsh git-pr-flow.ps1 view <number>
    pwsh git-pr-flow.ps1 merge <number> [-MergeMethod squash|rebase|merge]
    pwsh git-pr-flow.ps1 close <number>
"@
    exit 0
}

$ErrorActionPreference = 'Stop'

$remoteUrl = git remote get-url origin 2>$null
if (-not $remoteUrl) {
    Write-Error "No remote 'origin'."
    exit 1
}

$platform = if ($remoteUrl -match 'github') { 'github' }
            elseif ($remoteUrl -match 'gitee')  { 'gitee'  }
            else                                 { throw "Unsupported platform: $remoteUrl" }

$platformDir = Join-Path $PSScriptRoot '_platform'
. (Join-Path $platformDir "$platform.ps1")

# Auto-detect default branch if not provided
if (-not $Base) {
    $Base = if ($platform -eq 'gitee') { 'master' } else { 'main' }
}

switch ($Action) {
    'list' {
        $listFn = "${platform}_pr_list"
        & $listFn -State $State -Limit $Limit | Format-Table -AutoSize | Out-String | Write-Host
    }

    'new' {
        if (-not $Title) { Write-Error "Title required (-Title)"; exit 1 }
        if ($BodyFile -and (Test-Path $BodyFile)) { $Body = Get-Content $BodyFile -Raw }
        $newFn = "${platform}_pr_create"
        & $newFn -Title $Title -Body $Body -Base $Base -Head $Head -Draft:$Draft
    }

    'view' {
        if ($Number -le 0) { Write-Error "PR number required"; exit 1 }
        if ($platform -eq 'github') { gh pr view $Number }
        elseif ($platform -eq 'gitee') { gitee pr view $Number }
    }

    'merge' {
        if ($Number -le 0) { Write-Error "PR number required"; exit 1 }
        if ($platform -eq 'github') {
            gh pr merge $Number --$MergeMethod
        } elseif ($platform -eq 'gitee') {
            gitee pr merge $Number --$MergeMethod
        }
    }

    'close' {
        if ($Number -le 0) { Write-Error "PR number required"; exit 1 }
        if ($platform -eq 'github') { gh pr close $Number }
        elseif ($platform -eq 'gitee') { gitee pr close $Number }
    }
}

exit $LASTEXITCODE