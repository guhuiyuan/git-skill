#!/usr/bin/env pwsh
# git-stash-flow.ps1 — Stash management

param(
    [Parameter(Mandatory)] [ValidateSet('push','list','pop','apply','drop','show')] [string]$Action,
    [string]$Message = '',
    [switch]$IncludeUntracked = $false,
    [int]$Index = 0,
    [switch]$Help = $false
)

if ($Help) {
    @"
git-stash-flow — Stash management

USAGE:
    pwsh git-stash-flow.ps1 push [-Message "..."] [-IncludeUntracked]
    pwsh git-stash-flow.ps1 list
    pwsh git-stash-flow.ps1 pop [-Index 0]
    pwsh git-stash-flow.ps1 apply [-Index 0]
    pwsh git-stash-flow.ps1 drop [-Index 0]
    pwsh git-stash-flow.ps1 show [-Index 0]
"@
    exit 0
}

switch ($Action) {
    'push' {
        $args = @('stash', 'push')
        if ($Message) { $args += @('-m', $Message) }
        if ($IncludeUntracked) { $args += '-u' }
        git @args
    }
    'list' {
        git stash list
    }
    'pop' {
        $ref = if ($Index -gt 0) { "stash@{$Index}" } else { '' }
        git stash pop $ref
    }
    'apply' {
        $ref = if ($Index -gt 0) { "stash@{$Index}" } else { '' }
        git stash apply $ref
    }
    'drop' {
        $ref = if ($Index -gt 0) { "stash@{$Index}" } else { 'stash@{0}' }
        Write-Warning "Dropping $ref (will lose changes)"
        $ans = Read-Host "Confirm? [y/N]"
        if ($ans -in @('y','Y','yes')) { git stash drop $ref }
        else { Write-Host "Aborted."; exit 3 }
    }
    'show' {
        $ref = if ($Index -gt 0) { "stash@{$Index}" } else { 'stash@{0}' }
        git stash show -p $ref
    }
}

exit $LASTEXITCODE