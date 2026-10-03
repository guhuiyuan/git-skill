#!/usr/bin/env pwsh
# git-sync-flow.ps1 — Fetch / pull / sync with remote

param(
    [Parameter(Mandatory)] [ValidateSet('fetch','pull','sync')] [string]$Action,
    [string]$Remote = 'origin',
    [string]$Branch = '',
    [switch]$Rebase = $false,
    [switch]$AutoStash = $false,
    [switch]$Prune = $false,
    [switch]$Help = $false
)

if ($Help) {
    @"
git-sync-flow — Sync with remote

USAGE:
    pwsh git-sync-flow.ps1 fetch [-Remote origin] [-Prune]
    pwsh git-sync-flow.ps1 pull [-Rebase] [-AutoStash]
    pwsh git-sync-flow.ps1 sync [-Rebase]      # fetch + pull
"@
    exit 0
}

$ErrorActionPreference = 'Stop'

switch ($Action) {
    'fetch' {
        $args = @('fetch', $Remote)
        if ($Prune) { $args += '--prune' }
        git @args
    }
    'pull' {
        $args = @('pull', $Remote)
        if ($Branch) { $args += $Branch }
        if ($Rebase) { $args += '--rebase' }
        if ($AutoStash) { $args += @('--rebase', '--autostash') }
        git @args
    }
    'sync' {
        $args = @('fetch', $Remote, '--prune')
        git @args
        $args = @('pull', $Remote)
        if ($Rebase) { $args += '--rebase' }
        git @args
    }
}

exit $LASTEXITCODE