#!/usr/bin/env pwsh
# gitee.ps1 — Gitee platform adapter (oschina/gitee-cli + REST API fallback)
# Usage: dot-source: . ./gitee.ps1
# Provides: gitee_available, gitee_authenticated, gitee_repo_create, gitee_issue_create, gitee_pr_create

$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------
# Capability detection
# --------------------------------------------------------------------------

function gitee_available {
    return [bool](Get-Command gitee -ErrorAction SilentlyContinue)
}

function gitee_authenticated {
    if (-not (gitee_available)) { return $false }
    try {
        gitee auth status 2>&1 | Out-Null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

# --------------------------------------------------------------------------
# Token resolution
# --------------------------------------------------------------------------

function gitee_get_token {
    if ($env:GITEE_TOKEN) { return $env:GITEE_TOKEN }
    if (gitee_available) {
        try {
            return (gitee auth token 2>$null)
        } catch {}
    }
    return $null
}

# --------------------------------------------------------------------------
# REST API helper (Gitee uses query param ?access_token=, NOT header)
# --------------------------------------------------------------------------

function gitee_api_call {
    param(
        [Parameter(Mandatory)] [string]$Method,
        [Parameter(Mandatory)] [string]$Path,
        [hashtable]$Body
    )
    $token = gitee_get_token
    if (-not $token) {
        throw "No Gitee token. Run 'gitee auth login' or set GITEE_TOKEN."
    }

    $sep = if ($Path.Contains('?')) { '&' } else { '?' }
    $uri = "https://gitee.com/api/v5$Path${sep}access_token=$token"
    $headers = @{
        'Content-Type' = 'application/json;charset=UTF-8'
        'User-Agent'   = 'git-skill'
    }

    $params = @{
        Uri     = $uri
        Method  = $Method
        Headers = $headers
    }
    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10).Replace('"@(', '"').Replace(')"', '"')
        $params.ContentType = 'application/json;charset=UTF-8'
    }

    return Invoke-RestMethod @params
}

function gitee_repo_owner {
    $url = git remote get-url origin 2>$null
    if ($url -match '[:/]([^/]+)/([^/]+)(\.git)?$') {
        return @{ owner = $Matches[1]; repo = $Matches[2] }
    }
    return $null
}

# --------------------------------------------------------------------------
# Repo operations
# --------------------------------------------------------------------------

function gitee_repo_create {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [switch]$Private = $false,
        [string]$Description = '',
        [string]$Org = ''
    )

    if (gitee_available) {
        $visibility = if ($Private) { '--private' } else { '--public' }
        $args = @('repo', 'create', $Name, $visibility)
        if ($Description) { $args += @('--description', $Description) }
        if ($Org) { $args += @('--org', $Org) }
        & gitee @args
        if ($LASTEXITCODE -eq 0) { return $true }
    }

    # REST fallback
    $body = @{
        name        = $Name
        description = $Description
        @('private') = [bool]$Private
        auto_init   = $true
    }
    if ($Org) {
        $endpoint = "/orgs/$Org/repos"
    } else {
        $endpoint = '/user/repos'
    }

    try {
        $repo = gitee_api_call -Method POST -Path $endpoint -Body $body
        Write-Host "Created: $($repo.html_url)"
        return $true
    } catch {
        Write-Error "REST fallback failed: $_"
        return $false
    }
}

# --------------------------------------------------------------------------
# Issue operations
# --------------------------------------------------------------------------

function gitee_issue_create {
    param(
        [Parameter(Mandatory)] [string]$Title,
        [string]$Body = '',
        [string]$Labels = ''
    )

    $parts = gitee_repo_owner
    if (-not $parts) { throw "Cannot parse owner/repo from remote URL" }

    if (gitee_available) {
        $args = @('issue', 'create', '--title', $Title, '--body', $Body)
        & gitee @args
        return ($LASTEXITCODE -eq 0)
    }

    # REST fallback
    $payload = @{ title = $Title; body = $Body }
    gitee_api_call -Method POST -Path "/repos/$($parts.owner)/$($parts.repo)/issues" -Body $payload | Out-Null
    return $true
}

function gitee_issue_list {
    param(
        [ValidateSet('open','closed','all')] [string]$State = 'open',
        [int]$Limit = 30
    )
    $parts = gitee_repo_owner
    if (-not $parts) { throw "Cannot parse owner/repo from remote URL" }

    if (gitee_available) {
        & gitee issue list --state $State --limit $Limit
        return
    }

    $stateMap = @{ open = 'open'; closed = 'closed'; all = 'all' }
    gitee_api_call -Method GET -Path "/repos/$($parts.owner)/$($parts.repo)/issues?state=$($stateMap[$State])&per_page=$Limit"
}

# --------------------------------------------------------------------------
# Pull request operations
# --------------------------------------------------------------------------

function gitee_pr_create {
    param(
        [Parameter(Mandatory)] [string]$Title,
        [string]$Body = '',
        [string]$Base = 'master',
        [string]$Head,
        [switch]$Draft = $false
    )
    if (-not $Head) { $Head = (git branch --show-current) }

    $parts = gitee_repo_owner
    if (-not $parts) { throw "Cannot parse owner/repo from remote URL" }

    if (gitee_available) {
        $args = @('pr', 'create', '--title', $Title, '--body', $Body, '--base', $Base, '--head', $Head)
        & gitee @args
        return ($LASTEXITCODE -eq 0)
    }

    $payload = @{
        title = $Title
        body  = $Body
        head  = $Head
        base  = $Base
    }
    gitee_api_call -Method POST -Path "/repos/$($parts.owner)/$($parts.repo)/pulls" -Body $payload | Out-Null
    return $true
}

function gitee_pr_list {
    param(
        [ValidateSet('open','closed','merged','all')] [string]$State = 'open',
        [int]$Limit = 30
    )
    $parts = gitee_repo_owner
    if (-not $parts) { throw "Cannot parse owner/repo from remote URL" }

    if (gitee_available) {
        & gitee pr list --state $State --limit $Limit
        return
    }

    $stateMap = @{ open = 'open'; closed = 'closed'; merged = 'merged'; all = 'all' }
    gitee_api_call -Method GET -Path "/repos/$($parts.owner)/$($parts.repo)/pulls?state=$($stateMap[$State])&per_page=$Limit"
}