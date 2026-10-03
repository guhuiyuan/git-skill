<#
.SYNOPSIS
    proactive-advisor.ps1 - Detect context and suggest project management actions.
#>

[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "_lib\common.ps1")

$suggestions = @()

$isRepo = $false
$uncommittedCount = 0
$untrackedCount = 0
$branch = ""
$localCommitsAhead = 0
$hasRemote = $false
$remoteUrl = ""
$projectType = ""
$hasGitignore = $false
$hasReadme = $false
$hasLicense = $false
$sensitiveFilesPresent = @()
$totalBranches = 0
$mergedBranches = @()
$isDefaultBranch = $true

if (git rev-parse --is-inside-work-tree 2>$null) {
    $isRepo = $true
    try { $branch = (git symbolic-ref --short HEAD 2>$null) } catch { $branch = (git rev-parse --short HEAD 2>$null) }

    if (-not (git diff --quiet 2>$null)) {
        $uncommittedCount = (git diff --name-only 2>$null | Measure-Object).Count
    }
    $untrackedCount = (git ls-files --others --exclude-standard 2>$null | Measure-Object).Count

    if (git remote get-url origin 2>$null) {
        $hasRemote = $true
        $remoteUrl = (git remote get-url origin 2>$null)
    }

    $defaultBranch = (git remote show origin 2>$null | Select-String "HEAD branch:" | ForEach-Object { ($_ -split "HEAD branch:")[1].Trim() })
    if (-not $defaultBranch) { $defaultBranch = "main" }
    if ($branch -and $branch -ne $defaultBranch) { $isDefaultBranch = $false }

    if ($hasRemote) {
        try {
            $localCommitsAhead = [int](git rev-list --count "origin/$defaultBranch..HEAD" 2>$null)
        } catch { $localCommitsAhead = 0 }
    }

    $branches = @(git branch --format='%(refname:short)' 2>$null)
    $totalBranches = $branches.Count
    foreach ($b in $branches) {
        if ($b -eq $branch) { continue }
        if ($b) {
            try {
                $isAncestor = git merge-base --is-ancestor $b $defaultBranch 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $mergedBranches += $b
                }
            } catch {}
        }
    }

    if (Test-Path "package.json") { $projectType = "node" }
    if (Test-Path "pyproject.toml" -or (Test-Path "setup.py") -or (Test-Path "requirements.txt")) { $projectType = "python" }
    if (Test-Path "pom.xml" -or (Test-Path "build.gradle")) { $projectType = "java" }
    if (Test-Path "go.mod") { $projectType = "go" }
    if (Test-Path "Cargo.toml") { $projectType = "rust" }
    $csprojFiles = Get-ChildItem -Path . -Filter "*.csproj" -ErrorAction SilentlyContinue
    $slnFiles = Get-ChildItem -Path . -Filter "*.sln" -ErrorAction SilentlyContinue
    if ($csprojFiles -or $slnFiles) { $projectType = "dotnet" }

    if (Test-Path ".gitignore") { $hasGitignore = $true }
    if ((Test-Path "README.md") -or (Test-Path "readme.md") -or (Test-Path "README.rst") -or (Test-Path "README")) { $hasReadme = $true }
    if ((Test-Path "LICENSE") -or (Test-Path "LICENSE.md") -or (Test-Path "LICENSE.txt")) { $hasLicense = $true }

    foreach ($pattern in @(".env", ".env.local", "credentials.json", "*.pem", "*.key")) {
        $found = Get-ChildItem -Path . -Filter $pattern -ErrorAction SilentlyContinue
        if ($found) {
            $sensitiveFilesPresent += $pattern
        }
    }
}

function Add-Suggestion {
    param([string]$Priority, [string]$Command, [string]$Reason)
    $script:suggestions += @{
        priority = $Priority
        command  = $Command
        reason   = $Reason
    }
}

if ($isRepo) {
    $totalChanges = $uncommittedCount + $untrackedCount
    if ($totalChanges -ge 10) {
        Add-Suggestion "HIGH" "/git commit -m ..." "$totalChanges uncommitted files accumulated"
    } elseif ($totalChanges -ge 5) {
        Add-Suggestion "MEDIUM" "/git commit -m ..." "$totalChanges files modified"
    }
}

if ($isRepo -and -not $isDefaultBranch) {
    if ($uncommittedCount -gt 0 -or $untrackedCount -gt 0) {
        Add-Suggestion "LOW" "/git status" "On non-default branch $branch with uncommitted work"
    }
}

if ($projectType -and -not $hasGitignore) {
    Add-Suggestion "HIGH" "/git gitignore" "Detected $projectType project without .gitignore"
}

if ($isRepo -and -not $hasReadme) {
    $srcFiles = @(Get-ChildItem -Path . -Recurse -Depth 3 -Include "*.py","*.js","*.ts","*.go","*.rs","*.java" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike "*.git*" })
    if ($srcFiles.Count -ge 3) {
        Add-Suggestion "MEDIUM" "/git readme" "Project has $($srcFiles.Count) source files but no README"
    }
}

if ($isRepo -and -not $hasLicense) {
    Add-Suggestion "MEDIUM" "/git license" "No LICENSE file detected"
}

if ($localCommitsAhead -ge 5) {
    Add-Suggestion "HIGH" "/git push && /git pr new" "$localCommitsAhead commits ahead of remote"
} elseif ($localCommitsAhead -ge 1) {
    Add-Suggestion "MEDIUM" "/git push" "$localCommitsAhead commit(s) not pushed"
}

if ($isRepo -and -not $hasRemote) {
    try {
        $commitCount = [int](git rev-list --count HEAD 2>$null)
    } catch { $commitCount = 0 }
    if ($commitCount -ge 1) {
        Add-Suggestion "HIGH" "/git create-repo --platform <github|gitee>" "Local repo has $commitCount commit(s) but no remote configured"
    }
}

if ($sensitiveFilesPresent.Count -gt 0) {
    Add-Suggestion "HIGH" "/git scan && add $($sensitiveFilesPresent[0]) to .gitignore" "Sensitive file(s) in working tree: $($sensitiveFilesPresent -join ', ')"
}

if ($mergedBranches.Count -gt 0) {
    Add-Suggestion "LOW" "/git branch delete <name>" "$($mergedBranches.Count) merged branch(es) can be cleaned: $(($mergedBranches | Select-Object -First 3) -join ', ')"
}

if ($isRepo -and -not $isDefaultBranch -and $hasRemote) {
    try {
        $branchTimestamp = [int](git log -1 --format=%ct $branch 2>$null)
        $branchAgeDays = [int]((Get-Date) - (Get-Date -UnixTime $branchTimestamp)).TotalDays
    } catch { $branchAgeDays = 0 }
    if ($branchAgeDays -ge 14) {
        Add-Suggestion "MEDIUM" "/git rebase <default-branch>" "Branch $branch is $branchAgeDays days old; consider rebasing"
    }
}

if ($Quiet -and $suggestions.Count -eq 0) {
    exit 0
}

if ($Json) {
    @{
        suggestions = $suggestions
    } | ConvertTo-Json -Compress -Depth 5
} else {
    if ($suggestions.Count -eq 0) {
        if (-not $Quiet) {
            Write-Host "[ok] No proactive suggestions right now. Continue your work!" -ForegroundColor Green
        }
        exit 0
    }
    Write-Host ""
    Write-Host "Proactive suggestions:" -ForegroundColor Cyan
    foreach ($s in $suggestions) {
        $color = switch ($s.priority) {
            'HIGH'   { 'Red' }
            'MEDIUM' { 'Yellow' }
            default  { 'Cyan' }
        }
        $tag = switch ($s.priority) {
            'HIGH'   { '[HIGH]' }
            'MEDIUM' { '[MED] ' }
            default  { '[LOW] ' }
        }
        Write-Host "  $tag $($s.command)" -ForegroundColor $color
        Write-Host "     -> $($s.reason)"
    }
    Write-Host ""
}