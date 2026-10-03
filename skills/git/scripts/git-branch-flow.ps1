#!/usr/bin/env pwsh
# git-branch-flow.ps1 — Branch management (new/switch/list/delete/rename)
# Usage: pwsh git-branch-flow.ps1 <action> <name> [--from main] [--force]

param(
    [Parameter(Mandatory)] [ValidateSet('list','new','switch','delete','rename','prune')] [string]$Action,
    [string]$Name = '',
    [string]$From = '',
    [switch]$Force = $false,
    [switch]$All = $false,
    [switch]$Help = $false
)

if ($Help -or -not $Action) {
    @"
git-branch-flow — Branch management

USAGE:
    pwsh git-branch-flow.ps1 list [-All]
    pwsh git-branch-flow.ps1 new <name> [-From main]
    pwsh git-branch-flow.ps1 switch <name>
    pwsh git-branch-flow.ps1 delete <name> [-Force]
    pwsh git-branch-flow.ps1 rename <old> <new>
    pwsh git-branch-flow.ps1 prune

ACTIONS:
    list                List local branches
    new <name>          Create new branch
    switch <name>       Switch to branch
    delete <name>       Delete branch (refuses if unmerged, unless -Force)
    rename <old> <new>  Rename branch
    prune               Delete stale remote-tracking refs

OPTIONS:
    -From <branch>      Base for new branch (default: current)
    -Force              Force delete unmerged
    -All                List all (local + remote)
    --help, -h          Show this help

SAFETY:
    - main / master delete requires explicit Force + confirmation
"@
    exit 0
}

$ErrorActionPreference = 'Stop'

$libDir = Join-Path $PSScriptRoot '_lib'
. (Join-Path $libDir 'common.ps1')

if (-not (Test-Path '.git')) {
    Write-Error "Not a git repository."
    exit 1
}

switch ($Action) {
    'list' {
        $args = @('branch')
        if ($All) { $args += '-a' }
        git @args
    }

    'new' {
        if (-not $Name) { Write-Error "Branch name required"; exit 1 }
        if ($From) {
            git switch $From 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { Write-Error "Cannot switch to $From"; exit 1 }
            git switch -c $Name
        } else {
            git switch -c $Name
        }
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Created and switched to branch '$Name'" -ForegroundColor Green
        }
    }

    'switch' {
        if (-not $Name) { Write-Error "Branch name required"; exit 1 }
        git switch $Name
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Switched to '$Name'" -ForegroundColor Green
        }
    }

    'delete' {
        if (-not $Name) { Write-Error "Branch name required"; exit 1 }

        # Safety check on main/master
        if ($Name -in @('main','master')) {
            Write-Host ""
            Write-Host "✗ BLOCKED: Deleting $Name is not allowed via this skill." -ForegroundColor Red
            Write-Host "  Use raw git command if you really mean it."
            exit 1
        }

        $current = git branch --show-current
        if ($Name -eq $current) {
            Write-Error "Cannot delete the currently checked out branch. Switch first."
            exit 1
        }

        $flag = if ($Force) { '-D' } else { '-d' }

        # Confirmation for force
        if ($Force) {
            Write-Warning "Force-deleting branch '$Name' (unmerged commits will be lost)"
            $ans = Read-Host "Type 'delete' to confirm"
            if ($ans -ne 'delete') { Write-Host "Aborted."; exit 3 }
        }

        git branch $flag $Name
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Deleted branch '$Name'" -ForegroundColor Green
            Write-Host "  Tip: also prune stale remote ref: /git branch prune"
        }
    }

    'rename' {
        if (-not $Name) { Write-Error "Usage: rename <old> <new> (call as: -Name 'oldname newname')"; exit 1 }
        $parts = $Name -split ' ', 2
        if ($parts.Count -ne 2) { Write-Error "Rename requires both old and new name"; exit 1 }
        git branch -m $parts[0] $parts[1]
    }

    'prune' {
        git remote prune origin
        Write-Host "✓ Pruned stale remote-tracking refs" -ForegroundColor Green
    }
}

exit $LASTEXITCODE