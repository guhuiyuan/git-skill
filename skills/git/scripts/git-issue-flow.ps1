#!/usr/bin/env pwsh
# git-issue-flow.ps1 — Issue management (GitHub + Gitee)

param(
    [Parameter(Mandatory)] [ValidateSet('list','new','view','close','comment')] [string]$Action,
    [string]$Title = '',
    [string]$Body = '',
    [string]$BodyFile = '',
    [string]$Labels = '',
    [int]$Number = 0,
    [ValidateSet('open','closed','all')] [string]$State = 'open',
    [int]$Limit = 30,
    [switch]$Help = $false
)

if ($Help) {
    @"
git-issue-flow — Issue management

USAGE:
    pwsh git-issue-flow.ps1 list [-State open] [-Limit 30]
    pwsh git-issue-flow.ps1 new -Title "..." [-Body "..." | -BodyFile @file] [-Labels bug,help]
    pwsh git-issue-flow.ps1 view <number>
    pwsh git-issue-flow.ps1 close <number>
    pwsh git-issue-flow.ps1 comment <number> -Body "..."
"@
    exit 0
}

$ErrorActionPreference = 'Stop'

# Detect platform from remote
$remoteUrl = git remote get-url origin 2>$null
if (-not $remoteUrl) {
    Write-Error "No remote 'origin'. Clone or add remote first."
    exit 1
}

$platform = if ($remoteUrl -match 'github') { 'github' }
            elseif ($remoteUrl -match 'gitee')  { 'gitee'  }
            else                                 { throw "Unsupported platform. Remote: $remoteUrl" }

$platformDir = Join-Path $PSScriptRoot '_platform'
. (Join-Path $platformDir "$platform.ps1")

# Build labels list
$labelsList = @()
if ($Labels) { $labelsList = $Labels -split ',' | ForEach-Object { $_.Trim() } }

switch ($Action) {
    'list' {
        $listFn = "${platform}_issue_list"
        & $listFn -State $State -Limit $Limit | Format-Table -AutoSize | Out-String | Write-Host
    }

    'new' {
        if (-not $Title) { Write-Error "Title required"; exit 1 }
        if ($BodyFile -and (Test-Path $BodyFile)) { $Body = Get-Content $BodyFile -Raw }
        $newFn = "${platform}_issue_create"
        & $newFn -Title $Title -Body $Body -Labels $labelsList
    }

    'view' {
        if ($Number -le 0) { Write-Error "Issue number required"; exit 1 }
        if ($platform -eq 'github' -and (Get-Command gh -ErrorAction SilentlyContinue)) {
            gh issue view $Number
        } elseif ($platform -eq 'gitee' -and (Get-Command gitee -ErrorAction SilentlyContinue)) {
            gitee issue view $Number
        } else {
            Write-Host "(Web view recommended: $($remoteUrl -replace '\.git$', '')/issues/$Number)"
        }
    }

    'close' {
        if ($Number -le 0) { Write-Error "Issue number required"; exit 1 }
        if ($platform -eq 'github') { gh issue close $Number }
        elseif ($platform -eq 'gitee') { gitee issue close $Number }
    }

    'comment' {
        if ($Number -le 0) { Write-Error "Issue number required"; exit 1 }
        if (-not $Body) { Write-Error "Body required (-Body or -BodyFile)"; exit 1 }
        if ($platform -eq 'github') { gh issue comment $Number --body $Body }
        elseif ($platform -eq 'gitee') { gitee issue comment $Number --body $Body }
    }
}

exit $LASTEXITCODE