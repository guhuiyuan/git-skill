#!/usr/bin/env pwsh
# generate-gitignore.ps1 — Generate .gitignore for project languages

param(
    [string[]]$Languages = @(),
    [switch]$Auto = $false,
    [switch]$List = $false,
    [switch]$Fetch = $false,
    [switch]$Help = $false
)

if ($Help) {
    @"
generate-gitignore — Generate .gitignore from project detection

USAGE:
    pwsh generate-gitignore.ps1 [-Auto]
    pwsh generate-gitignore.ps1 -Languages node,python,java
    pwsh generate-gitignore.ps1 -List
    pwsh generate-gitignore.ps1 -Fetch -Languages python

OPTIONS:
    -Auto             Detect project languages automatically
    -Languages <list> Comma-separated language codes
    -List             List available templates
    -Fetch            Fetch latest from github/gitignore
"@
    exit 0
}

$ErrorActionPreference = 'Stop'

$libDir = Join-Path $PSScriptRoot '_lib'
. (Join-Path $libDir 'common.ps1')

$tplDir = Join-Path $PSScriptRoot '..\templates\gitignore'

if ($List) {
    Get-ChildItem $tplDir -Filter '*.gitignore' | ForEach-Object {
        $name = $_.BaseName -replace '\.gitignore$', ''
        Write-Host "  $name"
    }
    exit 0
}

if ($Auto) {
    $Languages = @(Detect-ProjectLanguage)
    if ($Languages.Count -eq 0) {
        Write-Host "No languages auto-detected. Falling back to 'os' + 'generic-ide'." -ForegroundColor Yellow
        $Languages = @('os', 'generic-ide')
    }
}

if ($Languages.Count -eq 0) {
    $ans = Read-Host "No language specified. Use OS-only template? [Y/n]"
    if ($ans -in @('n','N','no')) { exit 0 }
    $Languages = @('os')
}

# Always include OS template
if ($Languages -notcontains 'os') { $Languages += 'os' }

# Read existing .gitignore
$existing = ''
if (Test-Path '.gitignore') {
    Write-Host ".gitignore exists. Backing up to .gitignore.bak" -ForegroundColor Yellow
    $bakName = ".gitignore.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item '.gitignore' $bakName
    $existing = Get-Content '.gitignore' -Raw
}

# Aggregate new content
$newContent = @()
foreach ($lang in $Languages) {
    $tpl = Join-Path $tplDir "$lang.gitignore"
    if (Test-Path $tpl) {
        Write-Host "  + Adding $lang template" -ForegroundColor Green
        $newContent += Get-Content $tpl
    } else {
        Write-Warning "Template not found: $lang.gitignore"
    }
}

# Merge with existing (deduplicate)
$merged = @()
$seen = @{}
$all = ($existing -split "`n") + $newContent
foreach ($line in $all) {
    $trimmed = $line.Trim()
    if (-not $trimmed) { continue }
    if ($trimmed.StartsWith('#')) { $merged += $line; continue }
    if (-not $seen.ContainsKey($trimmed)) {
        $seen[$trimmed] = $true
        $merged += $line
    }
}

$merged | Out-File -FilePath '.gitignore' -Encoding utf8 -NoNewline
Write-Host ""
Write-Host "✓ .gitignore generated" -ForegroundColor Green
Write-Host "  Languages: $($Languages -join ', ')"