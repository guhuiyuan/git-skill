<#
.SYNOPSIS
    check-secrets.ps1 - Scan for secrets before commit/push.

.DESCRIPTION
    PowerShell port of check-secrets.sh. Uses gitleaks if available,
    falls back to embedded rules.

.PARAMETER Target
    staged | working-tree | all. Default: staged.

.PARAMETER Severity
    critical | high | low | all. Default: all.

.PARAMETER ForceAllowHigh
    Bypass HIGH findings (CRITICAL still blocks).

.PARAMETER NoGitleaks
    Skip gitleaks, use embedded rules only.

.PARAMETER Json
    JSON output for machine parsing.

.EXAMPLE
    .\check-secrets.ps1
    .\check-secrets.ps1 -Target all -Severity critical -Json
#>

[CmdletBinding()]
param(
    [ValidateSet('staged','working-tree','all')] [string]$Target = 'staged',
    [ValidateSet('critical','high','low','all')] [string]$Severity = 'all',
    [switch]$ForceAllowHigh,
    [switch]$NoGitleaks,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "_lib\common.ps1")

# ----- Embedded filename rules (PS hashtable) -----
$script:FilenameRules = @(
    @{sev='critical',pattern='.env'},
    @{sev='critical',pattern='.env.*'},
    @{sev='critical',pattern='*.pem'},
    @{sev='critical',pattern='*.key'},
    @{sev='critical',pattern='*.p12'},
    @{sev='critical',pattern='*.pfx'},
    @{sev='critical',pattern='id_rsa'},
    @{sev='critical',pattern='id_rsa.*'},
    @{sev='critical',pattern='id_ed25519'},
    @{sev='critical',pattern='id_ed25519.*'},
    @{sev='critical',pattern='id_dsa'},
    @{sev='critical',pattern='id_ecdsa'},
    @{sev='critical',pattern='*.keystore'},
    @{sev='critical',pattern='credentials.json'},
    @{sev='critical',pattern='service-account.json'},
    @{sev='critical',pattern='.npmrc'},
    @{sev='critical',pattern='.pypirc'},
    @{sev='critical',pattern='.netrc'},
    @{sev='critical',pattern='pgpass'},
    @{sev='critical',pattern='gha-creds-*'},
    @{sev='high',pattern='*.secret'},
    @{sev='high',pattern='*secret*'},
    @{sev='high',pattern='*password*'},
    @{sev='high',pattern='*credential*'},
    @{sev='high',pattern='*.sqlite'},
    @{sev='high',pattern='*.db'},
    @{sev='high',pattern='*.bak'},
    @{sev='high',pattern='*.swp'},
    @{sev='high',pattern='.DS_Store'},
    @{sev='low',pattern='*.log'},
    @{sev='low',pattern='*.tmp'},
    @{sev='low',pattern='node_modules'},
    @{sev='low',pattern='venv'},
    @{sev='low',pattern='__pycache__'},
    @{sev='low',pattern='target'},
    @{sev='low',pattern='build'},
    @{sev='low',pattern='dist'}
)

# ----- Embedded content rules -----
$script:ContentRules = @(
    @{sev='critical';name='aws-access-key';      pattern='AKIA[0-9A-Z]{16}'},
    @{sev='critical';name='aws-secret-key';      pattern='aws_secret_access_key[=:]["'']?[A-Za-z0-9/+=]{40}["'']?'},
    @{sev='critical';name='github-pat';          pattern='ghp_[A-Za-z0-9]{36}'},
    @{sev='critical';name='github-fine-grained'; pattern='github_pat_[A-Za-z0-9_]{82}'},
    @{sev='critical';name='github-oauth';        pattern='gho_[A-Za-z0-9]{36}'},
    @{sev='critical';name='github-user';         pattern='ghu_[A-Za-z0-9]{36}'},
    @{sev='critical';name='github-server';       pattern='ghs_[A-Za-z0-9]{36}'},
    @{sev='critical';name='github-refresh';      pattern='ghr_[A-Za-z0-9]{36}'},
    @{sev='critical';name='openai-api-key';      pattern='sk-[A-Za-z0-9]{20,}'},
    @{sev='critical';name='openai-project';      pattern='sk-proj-[A-Za-z0-9_-]{40,}'},
    @{sev='critical';name='anthropic-api-key';   pattern='sk-ant-[A-Za-z0-9_-]{40,}'},
    @{sev='critical';name='private-key';         pattern='-----BEGIN (RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY-----'},
    @{sev='critical';name='stripe-live-secret';  pattern='sk_live_[0-9a-zA-Z]{24,}'},
    @{sev='critical';name='stripe-live-restricted'; pattern='rk_live_[0-9a-zA-Z]{24,}'},
    @{sev='critical';name='google-api-key';      pattern='AIza[0-9A-Za-z_-]{35}'},
    @{sev='critical';name='jwt-token';           pattern='eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'},
    @{sev='critical';name='slack-token';         pattern='xox[baprs]-[0-9]{10,}-[0-9]{10,}-[A-Za-z0-9]{24,}'},
    @{sev='high';name='generic-password';     pattern='(password|passwd|pwd)[=:][\"''][^\"'']{8,}[\"'']'},
    @{sev='high';name='generic-api-key';        pattern='(api[_-]?key|token|secret)[=:][\"''][A-Za-z0-9_\-]{16,}[\"'']'}
)

# ----- Helper: severity filter check -----
function Test-SeverityMatches {
    param([string]$Sev, [string]$Filter)
    if ($Filter -eq 'all') { return $true }
    return ($Sev -eq $Filter)
}

# ----- Helper: glob match (PS -like) -----
function Test-FileMatchesGlob {
    param([string]$File, [string]$Pattern)
    return $File -like $Pattern
}

# ----- Get files to scan -----
function Get-ScanFiles {
    switch ($Target) {
        'staged'       { return (& git diff --cached --name-only --diff-filter=ACMR 2>$null) }
        'working-tree' { return (& git diff --name-only --diff-filter=ACMR 2>$null) }
        'all'          { return (& git ls-files 2>$null) }
    }
}

# ----- Get diff content for a file -----
function Get-DiffContent {
    param([string]$File)
    switch ($Target) {
        'staged'       { return (& git diff --cached -- $File 2>$null) }
        'working-tree' { return (& git diff -- $File 2>$null) }
        'all'          { return (& git show "HEAD:${File}" 2>$null) }
    }
}

# ----- Scan with gitleaks -----
function Invoke-GitleaksScan {
    if (-not (Test-HasCmd "gitleaks")) {
        return $false
    }
    Write-Host "[info] Using gitleaks (preferred)..." -ForegroundColor Cyan

    $gitleaksArgs = @('--no-banner', '--redact')
    $gitleaksConfig = Join-Path $Script:ReferencesDir "gitleaks.toml"
    if (Test-Path $gitleaksConfig) {
        $gitleaksArgs += @('--config', $gitleaksConfig)
    }

    switch ($Target) {
        'staged'       { $gitleaksArgs += @('protect', '--staged') }
        'working-tree' { $gitleaksArgs += @('detect', '--source', '.', '--no-git') }
        'all'          { $gitleaksArgs += @('detect', '--no-git') }
    }

    try {
        & gitleaks @gitleaksArgs 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

# ----- Scan with embedded rules -----
function Invoke-EmbeddedScan {
    Write-Host "[info] Using embedded rules (fallback)..." -ForegroundColor Cyan

    $findings = @()
    $criticalCount = 0
    $highCount = 0
    $lowCount = 0

    $files = Get-ScanFiles
    if (-not $files) { $files = @() }

    foreach ($file in $files) {
        if (-not $file) { continue }

        # Filename scan
        foreach ($rule in $script:FilenameRules) {
            if (-not (Test-SeverityMatches -Sev $rule.sev -Filter $Severity)) { continue }
            if (Test-FileMatchesGlob -File $file -Pattern $rule.pattern) {
                $findings += @{
                    severity = $rule.sev
                    file     = $file
                    match    = "filename: $($rule.pattern)"
                    rule     = "filename:$($rule.pattern)"
                }
                switch ($rule.sev) {
                    'critical' { $script:criticalCount = $script:criticalCount + 1; $criticalCount++ }
                    'high'     { $script:highCount = $script:highCount + 1; $highCount++ }
                    'low'      { $script:lowCount = $script:lowCount + 1; $lowCount++ }
                }
            }
        }

        # Content scan
        switch -Wildcard ($file) {
            '*.example' { continue }
            '*.sample'  { continue }
            '*.template'{ continue }
            '*.test'    { continue }
            '*.fixture' { continue }
            '*.md'      { continue }
            'LICENSE'   { continue }
            '.gitignore'{ continue }
        }

        $content = Get-DiffContent -File $file
        if (-not $content) { continue }

        foreach ($rule in $script:ContentRules) {
            if (-not (Test-SeverityMatches -Sev $rule.sev -Filter $Severity)) { continue }

            $match = [regex]::Match($content, $rule.pattern)
            if ($match.Success) {
                $findings += @{
                    severity = $rule.sev
                    file     = $file
                    match    = $match.Value.Substring(0, [Math]::Min(30, $match.Value.Length)) + "..."
                    rule     = $rule.name
                }
                switch ($rule.sev) {
                    'critical' { $criticalCount++ }
                    'high'     { $highCount++ }
                    'low'      { $lowCount++ }
                }
            }
        }
    }

    if ($Json) {
        $output = @{
            tool     = 'embedded'
            target   = $Target
            findings = $findings
        }
        $output | ConvertTo-Json -Compress -Depth 5
    } else {
        if ($findings.Count -eq 0) {
            Write-Host "[ok] No secrets detected in $Target." -ForegroundColor Green
            return
        }
        Write-Host "[warn] Found $($findings.Count) potential secret(s) in $Target" -ForegroundColor Yellow
        foreach ($f in $findings) {
            switch ($f.severity) {
                'critical' { Write-Host "[CRITICAL] $($f.file): $($f.rule)" -ForegroundColor Red }
                'high'     { Write-Host "[HIGH]     $($f.file): $($f.rule)" -ForegroundColor Yellow }
                'low'      { Write-Host "[LOW]      $($f.file): $($f.rule)" -ForegroundColor Cyan }
            }
        }
    }

    if ($criticalCount -gt 0) {
        if (-not $Json) {
            Write-Host ""
            Write-Host "[err] $criticalCount CRITICAL finding(s) cannot be bypassed." -ForegroundColor Red
            Write-Host "  Fix: rotate the secret, remove from history, or move to .gitignore." -ForegroundColor Red
        }
        exit 1
    }
    if ($highCount -gt 0) {
        if ($ForceAllowHigh) {
            if (-not $Json) {
                Write-Host "[warn] $highCount HIGH finding(s) BYPASSED with -ForceAllowHigh." -ForegroundColor Yellow
            }
            exit 3
        }
        if (-not $Json) {
            Write-Host "[err] $highCount HIGH finding(s). Use -ForceAllowHigh to override." -ForegroundColor Red
        }
        exit 2
    }
    if ($lowCount -gt 0 -and -not $Json) {
        Write-Host "[warn] $lowCount LOW warning(s) only. Continuing." -ForegroundColor Yellow
    }
}

# ----- Main -----
$useGitleaks = (-not $NoGitleaks) -and (Test-HasCmd "gitleaks")
if ($useGitleaks) {
    $clean = Invoke-GitleaksScan
    if ($clean) { exit 0 }
    if (-not $Json) {
        Write-Host "[err] gitleaks detected secrets. Rotate, remove, or use secret manager." -ForegroundColor Red
    }
    exit 1
} else {
    Invoke-EmbeddedScan
}