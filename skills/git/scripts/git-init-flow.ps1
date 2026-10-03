#!/usr/bin/env pwsh
# git-init-flow.ps1 — Full init flow: init + .gitignore + secret scan + first commit
# Usage: pwsh git-init-flow.ps1 [--branch main] [--no-initial-commit]

param(
    [string]$Branch = 'main',
    [switch]$NoInitialCommit = $false,
    [switch]$Help = $false
)

if ($Help) {
    @"
git-init-flow — Initialize a git repo with best practices

USAGE:
    pwsh git-init-flow.ps1 [--branch main] [--no-initial-commit]

OPTIONS:
    --branch <name>           Default branch name (default: main)
    --no-initial-commit       Skip the initial commit step
    --help, -h                Show this help

STEPS:
    1. Verify cwd is not already a git repo
    2. Detect project language(s)
    3. Generate .gitignore
    4. (optional) Generate README
    5. (optional) Generate LICENSE
    6. git init with specified branch
    7. Initial add + commit (unless --no-initial-commit)
"@
    exit 0
}

$ErrorActionPreference = 'Stop'

# Source common library
$libDir = Join-Path $PSScriptRoot '_lib'
. (Join-Path $libDir 'common.ps1')

if (Test-Path '.git') {
    Write-Warning "Already a git repo (.git exists). Use 'git-init-flow' only on fresh projects."
    exit 1
}

Write-Host "Initializing new git repository in $((Get-Location).Path)" -ForegroundColor Cyan

# 1. Detect languages
$langs = @(Detect-ProjectLanguage)
Write-Host "Detected project types: $($langs -join ', ')" -ForegroundColor Green

# 2. Generate .gitignore
if (-not (Test-Path '.gitignore')) {
    Write-Host "Generating .gitignore..."
    & (Join-Path $PSScriptRoot 'generate-gitignore.ps1') @langs
} else {
    Write-Host ".gitignore already exists, skipping generation" -ForegroundColor Yellow
}

# 3. README
if (-not (Test-Path 'README.md') -and -not (Test-Path 'README')) {
    $ans = Read-Host "Generate README.md? [Y/n]"
    if ($ans -notin @('n','N','no','No','NO')) {
        & (Join-Path $PSScriptRoot 'generate-readme.ps1') --style standard --name (Split-Path -Leaf (Get-Location).Path)
    }
}

# 4. LICENSE
if (-not (Test-Path 'LICENSE') -and -not (Test-Path 'LICENSE.md')) {
    $ans = Read-Host "Generate LICENSE? [y/N]"
    if ($ans -in @('y','Y','yes','Yes','YES')) {
        & (Join-Path $PSScriptRoot 'generate-license.ps1')
    }
}

# 5. git init
git init --initial-branch $Branch 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "git init failed"
    exit 1
}

git config user.name  2>$null
if ($LASTEXITCODE -ne 0) {
    $name  = Read-Host "git user.name not set. Enter your name"
    $email = Read-Host "git user.email"
    git config user.name  $name
    git config user.email $email
}

# 6. Initial commit (with secret scan)
if (-not $NoInitialCommit) {
    git add .
    Write-Host "Running secret scan before initial commit..." -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot 'check-secrets.ps1') --severity critical
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "CRITICAL secrets detected. Review before committing."
        $ans = Read-Host "Continue with initial commit anyway? (NOT recommended) [y/N]"
        if ($ans -notin @('y','Y','yes','Yes','YES')) {
            Write-Host "Aborted. Fix the secrets or add them to .gitignore first."
            exit 2
        }
    }
    git commit -m "feat: initial commit"
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Initial commit failed"
        exit 1
    }
}

Write-Host ""
Write-Host "✓ Repository initialized successfully" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  /git create-repo --platform github|gitee   # create remote"
Write-Host "  /git remote add origin <url>                # or add existing remote"
Write-Host "  /git push -u origin $Branch                 # push first commit"