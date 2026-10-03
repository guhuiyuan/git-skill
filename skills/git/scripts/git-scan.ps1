#!/usr/bin/env pwsh
# git-scan.ps1 — Manual secret scan (alias of check-secrets.sh with default flags)

param(
    [ValidateSet('staged','working-tree','all')] [string]$Scope = 'staged',
    [ValidateSet('critical','high','low','critical,high','all')] [string]$Severity = 'critical,high,low',
    [switch]$ForceAllowHigh = $false,
    [switch]$Json = $false,
    [switch]$Help = $false
)

if ($Help) {
    @"
git-scan — Manual secret scan

USAGE:
    pwsh git-scan.ps1 [-Scope staged|working-tree|all] [-Severity <list>] [-ForceAllowHigh] [-Json]

DEFAULTS:
    -Scope    = staged (current changes)
    -Severity = critical,high,low (all)

EXAMPLES:
    pwsh git-scan.ps1                            # scan staged, all severities
    pwsh git-scan.ps1 -Severity critical         # only critical
    pwsh git-scan.ps1 -Scope working-tree        # scan working tree
    pwsh git-scan.ps1 -Scope all                 # scan full history
"@
    exit 0
}

$args = @('--severity', $Severity)
if ($ForceAllowHigh) { $args += '--force-allow-high' }
if ($Json) { $args += '--json' }
switch ($Scope) {
    'staged'       { $args += '--staged' }
    'working-tree' { $args += '--working-tree' }
    'all'          { $args += '--all' }
}

& (Join-Path $PSScriptRoot 'check-secrets.ps1') @args
exit $LASTEXITCODE