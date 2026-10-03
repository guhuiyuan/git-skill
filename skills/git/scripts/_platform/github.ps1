#!/usr/bin/env pwsh
# github.ps1 — GitHub platform adapter (gh CLI + REST API fallback)
# Usage: source this script (dot-source it): . ./github.ps1
# Provides: gh_available, gh_repo_create, gh_issue_create, gh_pr_create, gh_api_call

$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------
# Capability detection
# --------------------------------------------------------------------------

function gh_available {
    return [bool](Get-Command gh -ErrorAction SilentlyContinue)
}

function gh_authenticated {
    if (-not (gh_available)) { return $false }
    try {
        $status = gh auth status 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function gh_current_user {
    if (-not (gh_authenticated)) { return $null }
    return (gh api user --jq .login 2>$null)
}

# --------------------------------------------------------------------------
# Token resolution
# --------------------------------------------------------------------------

function gh_get_token {
    # Priority: GH_TOKEN env > keychain > gh CLI internal
    if ($env:GH_TOKEN) { return $env:GH_TOKEN }

    # Try keychain via cmdkey (Windows Credential Manager)
    try {
        $cred = cmdkey /list:github 2>$null | Select-String -Pattern "Target: github"
        if ($cred) {
            # cmdkey /list only shows that a credential exists, not the value.
            # We rely on GH_TOKEN env or CLI; return null here.
            return $null
        }
    } catch {}

    # Fall back to gh CLI internal storage (via `gh auth token`)
    if (gh_available) {
        try {
            return (gh auth token 2>$null)
        } catch {}
    }
    return $null
}

# --------------------------------------------------------------------------
# REST API helper (used as fallback when gh is not available)
# --------------------------------------------------------------------------

function gh_api_call {
    param(
        [Parameter(Mandatory)] [string]$Method,
        [Parameter(Mandatory)] [string]$Path,
        [hashtable]$Body
    )
    $token = gh_get_token
    if (-not $token) {
        throw "No GitHub token available. Run 'gh auth login' or set GH_TOKEN."
    }

    $uri = "https://api.github.com$Path"
    $headers = @{
        'Authorization'        = "token $token"
        'Accept'               = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
        'User-Agent'           = 'git-skill'
    }

    $params = @{
        Uri             = $uri
        Method          = $Method
        Headers         = $headers
        ContentType     = 'application/json'
    }
    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10)
    }

    return Invoke-RestMethod @params
}

# --------------------------------------------------------------------------
# Repo operations
# --------------------------------------------------------------------------

function gh_repo_create {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [switch]$Private = $false,
        [string]$Description = '',
        [string]$Org = ''
    )

    $visibility = if ($Private) { '--private' } else { '--public' }
    $desc_args  = if ($Description) { @('--description', $Description) } else { @() }
    $org_args   = if ($Org) { @('--org', $Org) } else { @() }

    if (gh_available) {
        $args = @('repo', 'create', $Name, $visibility) + $desc_args + $org_args + @('--source', '.', '--remote', '--push')
        & gh @args
        if ($LASTEXITCODE -eq 0) { return $true }
    }

    # Fallback to REST
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
        $repo = gh_api_call -Method POST -Path $endpoint -Body $body
        Write-Host "Created: https://github.com/$($repo.owner.login)/$($repo.name)"
        return $true
    } catch {
        Write-Error "REST fallback failed: $_"
        return $false
    }
}

# --------------------------------------------------------------------------
# Issue operations
# --------------------------------------------------------------------------

function gh_issue_create {
    param(
        [Parameter(Mandatory)] [string]$Title,
        [string]$Body = '',
        [string[]]$Labels = @()
    )

    $owner = (git remote get-url origin 2>$null) -replace '.*[:/]([^/]+)/[^/]+(\.git)?$', '$1'
    $repo  = (git remote get-url origin 2>$null) -replace '.*/([^/]+)(\.git)?$', '$1'

    if (gh_available) {
        $args = @('issue', 'create', '--title', $Title, '--body', $Body)
        foreach ($l in $Labels) { $args += @('--label', $l) }
        & gh @args
        return ($LASTEXITCODE -eq 0)
    }

    # REST fallback
    $payload = @{ title = $Title; body = $Body }
    if ($Labels.Count -gt 0) { $payload.labels = $Labels }
    gh_api_call -Method POST -Path "/repos/$owner/$repo/issues" -Body $payload | Out-Null
    return $true
}

function gh_issue_list {
    param(
        [ValidateSet('open','closed','all')] [string]$State = 'open',
        [int]$Limit = 30
    )
    if (gh_available) {
        & gh issue list --state $State --limit $Limit
        return
    }
    $owner = (git remote get-url origin 2>$null) -replace '.*[:/]([^/]+)/[^/]+(\.git)?$', '$1'
    $repo  = (git remote get-url origin 2>$null) -replace '.*/([^/]+)(\.git)?$', '$1'
    gh_api_call -Method GET -Path "/repos/$owner/$repo/issues?state=$State&per_page=$Limit"
}

# --------------------------------------------------------------------------
# Pull request operations
# --------------------------------------------------------------------------

function gh_pr_create {
    param(
        [Parameter(Mandatory)] [string]$Title,
        [string]$Body = '',
        [string]$Base = 'main',
        [string]$Head,
        [switch]$Draft = $false
    )
    if (-not $Head) { $Head = (git branch --show-current) }

    if (gh_available) {
        $args = @('pr', 'create', '--title', $Title, '--body', $Body, '--base', $Base, '--head', $Head)
        if ($Draft) { $args += '--draft' }
        & gh @args
        return ($LASTEXITCODE -eq 0)
    }

    # REST fallback
    $owner = (git remote get-url origin 2>$null) -replace '.*[:/]([^/]+)/[^/]+(\.git)?$', '$1'
    $repo  = (git remote get-url origin 2>$null) -replace '.*/([^/]+)(\.git)?$', '$1'
    $payload = @{ title = $Title; body = $Body; head = $Head; base = $Base; draft = [bool]$Draft }
    gh_api_call -Method POST -Path "/repos/$owner/$repo/pulls" -Body $payload | Out-Null
    return $true
}

function gh_pr_list {
    param(
        [ValidateSet('open','closed','merged','all')] [string]$State = 'open',
        [int]$Limit = 30
    )
    if (gh_available) {
        & gh pr list --state $State --limit $Limit
        return
    }
    $owner = (git remote get-url origin 2>$null) -replace '.*[:/]([^/]+)/[^/]+(\.git)?$', '$1'
    $repo  = (git remote get-url origin 2>$null) -replace '.*/([^/]+)(\.git)?$', '$1'
    gh_api_call -Method GET -Path "/repos/$owner/$repo/pulls?state=$State&per_page=$Limit"
}