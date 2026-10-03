#!/usr/bin/env pwsh
# generate-license.ps1 — Generate LICENSE file from template

param(
    [ValidateSet('MIT','Apache-2.0','GPL-3.0','BSD-3-Clause','Unlicense')] [string]$Type = '',
    [string]$Name = '',
    [int]$Year = 0,
    [switch]$List = $false,
    [switch]$Help = $false
)

if ($Help -or $List) {
    @"
generate-license — Generate LICENSE file

USAGE:
    pwsh generate-license.ps1 -Type MIT -Name "Your Name" [-Year 2026]

AVAILABLE LICENSES:
    MIT            Permissive, ~45% of GitHub (recommended default)
    Apache-2.0     Permissive + patent grant
    GPL-3.0        Strong copyleft
    BSD-3-Clause  Permissive + non-endorsement
    Unlicense      Public domain dedication

NOTE:
    Refuses to overwrite existing LICENSE (legal file).
"@
    exit 0
}

$ErrorActionPreference = 'Stop'

if (Test-Path 'LICENSE') {
    Write-Error "LICENSE already exists. Refusing to overwrite (legal file)."
    Write-Host "  Remove it manually if you really want to replace it."
    exit 1
}

if (-not $Type) {
    Write-Host "Available licenses:"
    @('MIT','Apache-2.0','GPL-3.0','BSD-3-Clause','Unlicense') | ForEach-Object { Write-Host "  $_" }
    $Type = Read-Host "Choose license type"
}

if (-not $Name) { $Name = Read-Host "Copyright holder name" }
if ($Year -eq 0) { $Year = (Get-Date).Year }

$tplDir = Join-Path $PSScriptRoot '..\templates\license'
$tplFile = Join-Path $tplDir "$Type.txt"
if (-not (Test-Path $tplFile)) {
    Write-Error "License template not found: $Type.txt"
    exit 1
}

$content = Get-Content $tplFile -Raw
$content = $content.Replace('{{YEAR}}', $Year.ToString())
$content = $content.Replace('{{NAME}}', $Name)

$content | Out-File 'LICENSE' -Encoding utf8 -NoNewline
Write-Host ""
Write-Host "✓ LICENSE created ($Type)" -ForegroundColor Green
Write-Host "  Copyright (c) $Year $Name"