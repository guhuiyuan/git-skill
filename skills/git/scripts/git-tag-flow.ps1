#!/usr/bin/env pwsh
# git-tag-flow.ps1 — Tag management

param(
    [Parameter(Mandatory)] [ValidateSet('list','create','delete','push')] [string]$Action,
    [string]$Name = '',
    [string]$Message = '',
    [switch]$Annotate = $false,
    [switch]$Sign = $false,
    [switch]$Force = $false,
    [switch]$Help = $false
)

if ($Help) {
    @"
git-tag-flow — Tag management

USAGE:
    pwsh git-tag-flow.ps1 list
    pwsh git-tag-flow.ps1 create <name> [-Message "..."] [-Annotate] [-Sign]
    pwsh git-tag-flow.ps1 delete <name>
    pwsh git-tag-flow.ps1 push <name|all>

"@
    exit 0
}

switch ($Action) {
    'list' {
        git tag --list | Sort-Object | ForEach-Object { Write-Host $_ }
    }
    'create' {
        if (-not $Name) { Write-Error "Tag name required"; exit 1 }
        $args = @('tag', $Name)
        if ($Annotate -or $Message) { $args += '-a' }
        if ($Message) { $args += @('-m', $Message) }
        if ($Sign) { $args += '-s' }
        git @args
    }
    'delete' {
        if (-not $Name) { Write-Error "Tag name required"; exit 1 }
        if ($Force) {
            git tag -d $Name
        } else {
            git tag -d $Name 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                $ans = Read-Host "Local delete failed (probably pushed). Force delete? [y/N]"
                if ($ans -in @('y','Y','yes')) { git tag -d $Name }
                else { exit 3 }
            }
        }
    }
    'push' {
        if (-not $Name) { Write-Error "Tag name or 'all' required"; exit 1 }
        if ($Name -eq 'all') {
            git push --tags
        } else {
            git push origin $Name
        }
    }
}

exit $LASTEXITCODE