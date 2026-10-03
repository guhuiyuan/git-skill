<#
.SYNOPSIS
    common.ps1 - Shared library for git-skill PowerShell scripts.
.DESCRIPTION
    Source this file (dot-source) from any script:
        . "$PSScriptRoot\_lib\common.ps1"
#>

$ErrorActionPreference = 'Stop'

# ----- Constants -----
$Script:GIT_SKILL_VERSION = "1.0.0"

# ----- Resolve paths -----
$Script:_LibCommonFile = $MyInvocation.MyCommand.Path
if (-not $Script:_LibCommonFile) {
    $Script:_LibCommonFile = $PSCommandPath
}
$Script:_LibDir = Split-Path -Parent $Script:_LibCommonFile
$Script:ScriptsDir = Split-Path -Parent $Script:_LibDir
$Script:SkillDir = Split-Path -Parent $Script:ScriptsDir
$Script:TemplatesDir = Join-Path $Script:SkillDir "templates"
$Script:ReferencesDir = Join-Path $Script:SkillDir "references"

# ----- Color helpers -----
$Script:Cyan   = [ConsoleColor]::Cyan
$Script:Green  = [ConsoleColor]::Green
$Script:Yellow = [ConsoleColor]::Yellow
$Script:Red    = [ConsoleColor]::Red
$Script:Gray   = [ConsoleColor]::Gray
$Script:Reset  = [ConsoleColor]::Gray  # Used as fallback

function Write-Log {
    param(
        [Parameter(Mandatory)] [ValidateSet('info','ok','warn','err','debug')] [string]$Level,
        [Parameter(Mandatory, ValueFromRemainingArguments)] [string]$Message
    )
    if ($Level -eq 'debug' -and -not $env:DEBUG) { return }
    $color = switch ($Level) {
        'info'  { $Script:Cyan }
        'ok'    { $Script:Green }
        'warn'  { $Script:Yellow }
        'err'   { $Script:Red }
        'debug' { $Script:Gray }
        default { $Script:Reset }
    }
    $prefix = "[$Level]"
    Write-Host "$prefix $Message" -ForegroundColor $color
}

Set-Alias -Name log_info  -Value Write-Log -Scope Script -Force
Set-Alias -Name log_ok    -Value Write-Log -Scope Script -Force
Set-Alias -Name log_warn  -Value Write-Log -Scope Script -Force
Set-Alias -Name log_debug -Value Write-Log -Scope Script -Force

function log_err {
    param([Parameter(Mandatory, ValueFromRemainingArguments)] [string]$Message)
    Write-Host "[err] $Message" -ForegroundColor $Script:Red
    exit 1
}

# ----- Argument parsing -----
$Script:DryRun = $false
$Script:OutputFormat = "human"

function Parse-CommonFlags {
    param([Parameter(ValueFromRemainingArguments)] [string[]]$Args)
    while ($Args.Count -gt 0) {
        switch ($Args[0]) {
            '--dry-run'   { $Script:DryRun = $true; $Args = $Args[1..($Args.Count - 1)] }
            '--verbose'   { $env:DEBUG = "1"; $Args = $Args[1..($Args.Count - 1)] }
            '-v'          { $env:DEBUG = "1"; $Args = $Args[1..($Args.Count - 1)] }
            '--json'      { $Script:OutputFormat = "json"; $Args = $Args[1..($Args.Count - 1)] }
            '--no-color'  { $env:NO_COLOR = "1"; $Args = $Args[1..($Args.Count - 1)] }
            '--help'      { if (Get-Command -Name 'print_usage' -ErrorAction SilentlyContinue) { print_usage; exit 0 }; $Args = $Args[1..($Args.Count - 1)] }
            '-h'          { if (Get-Command -Name 'print_usage' -ErrorAction SilentlyContinue) { print_usage; exit 0 }; $Args = $Args[1..($Args.Count - 1)] }
            '--'          { $Args = $Args[1..($Args.Count - 1)]; break }
            default { break }
        }
    }
    return ,$Args
}

# ----- Run command (respects DryRun) -----
function Invoke-Cmd {
    param([Parameter(ValueFromRemainingArguments)] [string[]]$Cmd)
    if ($Script:DryRun) {
        log_info @("[dryRun]", ($Cmd -join ' '))
        return
    }
    & $Cmd[0] @($Cmd[1..($Cmd.Count - 1)])
}

# ----- Pre-flight checks -----
function Assert-GitRepo {
    if (-not (git rev-parse --is-inside-work-tree 2>$null)) {
        log_err @("Not a git repository. Run /git init first, or /git clone <url>.")
    }
}

# ----- Exit codes -----
$Script:ExitOk = 0
$Script:ExitGeneral = 1
$Script:ExitBlocked = 2
$Script:ExitWarned = 3

# ----- Severity -----
$Script:SeverityCritical = 3
$Script:SeverityHigh = 2
$Script:SeverityLow = 1

# ----- Platform detection -----
function Get-CurrentOS {
    if ($IsWindows) { return "windows" }
    if ($IsMacOS)   { return "macos" }
    if ($IsLinux)   { return "linux" }
    return "unknown"
}

# ----- Check command exists -----
function Test-HasCmd {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}