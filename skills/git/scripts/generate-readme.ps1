#!/usr/bin/env pwsh
# generate-readme.ps1 — Generate README.md template

param(
    [ValidateSet('minimal','standard','detailed')] [string]$Style = 'standard',
    [string]$Name = '',
    [string]$Description = '',
    [string]$ProjectName = '',
    [switch]$Help = $false
)

if ($Help) {
    @"
generate-readme — Generate README.md template

USAGE:
    pwsh generate-readme.ps1 [-Style minimal|standard|detailed] [-Name <project>] [-Description <text>]
"@
    exit 0
}

$ErrorActionPreference = 'Stop'

$tplDir = Join-Path $PSScriptRoot '..\templates\readme'

if (Test-Path 'README.md') {
    Write-Warning "README.md already exists. Refusing to overwrite."
    $ans = Read-Host "Append a generated section instead? [y/N]"
    if ($ans -in @('y','Y','yes')) {
        # Append mode handled below
    } else {
        exit 0
    }
}

$tplFile = Join-Path $tplDir "README.$Style.md"
if (-not (Test-Path $tplFile)) {
    Write-Error "Template not found: README.$Style.md"
    exit 1
}

if (-not $Name) { $Name = Split-Path -Leaf (Get-Location).Path }
if (-not $Description) {
    $desc = Read-Host "Brief description (one line)"
    if ($desc) { $Description = $desc }
}

$content = Get-Content $tplFile -Raw
$content = $content.Replace('{{NAME}}', $Name)
$content = $content.Replace('{{DESCRIPTION}}', $Description)

if (Test-Path 'README.md') {
    Add-Content 'README.md' "`n---`n`n$content"
    Write-Host "✓ Section appended to existing README.md" -ForegroundColor Green
} else {
    $content | Out-File 'README.md' -Encoding utf8 -NoNewline
    Write-Host "✓ README.md created ($Style)" -ForegroundColor Green
}