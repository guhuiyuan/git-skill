#!/usr/bin/env bash
#
# auth-detect.sh — Detect and guide authentication setup for GitHub / Gitee.
#
# Priority order (matches industry best practice):
#   1. gh CLI auth (GitHub)
#   2. gitee CLI auth (Gitee)
#   3. Environment variables (GH_TOKEN / GITEE_TOKEN)
#   4. SSH (key registered on platform)
#   5. None → guided setup wizard

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

# Source platform adapters
# shellcheck source=_platform/github.sh
source "${SCRIPT_DIR}/_platform/github.sh"
# shellcheck source=_platform/gitee.sh
source "${SCRIPT_DIR}/_platform/gitee.sh"

print_usage() {
  cat <<EOF
Usage: auth-detect.sh [--platform github|gitee] [--guide]

Options:
  --platform NAME    Check specific platform (default: auto from remote)
  --guide            Print interactive setup guide even if auth is OK
  --json             JSON output

Without flags, this script:
  - Detects platform from remote URL
  - Reports current auth status
  - If unauthenticated, prints setup guide
EOF
}

PLATFORM=""
GUIDE=false
JSON_OUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) PLATFORM="$2"; shift 2 ;;
    --guide)    GUIDE=true; shift ;;
    --json)     JSON_OUT=true; OUTPUT_FORMAT=json; shift ;;
    --help|-h)  print_usage; exit 0 ;;
    *) log_err "Unknown: $1" ;;
  esac
done

# ----- Detect platform if not specified -----
if [[ -z "${PLATFORM}" ]]; then
  if has_cmd "${SCRIPT_DIR}/platform-detect.sh"; then
    PLATFORM="$("${SCRIPT_DIR}/platform-detect.sh")"
  fi
fi

# ----- GitHub auth -----
check_github() {
  local method="none"
  local hint=""
  if has_cmd gh && gh auth status >/dev/null 2>&1; then
    method="gh-cli"
  elif [[ -n "${GH_TOKEN:-}" ]]; then
    method="token"
  elif [[ -f "${HOME}/.ssh/id_ed25519" ]] || [[ -f "${HOME}/.ssh/id_rsa" ]]; then
    if ssh -T -o BatchMode=yes -o ConnectTimeout=5 git@github.com 2>&1 | grep -q "successfully authenticated"; then
      method="ssh"
    fi
  fi

  if [[ "${JSON_OUT}" == "true" ]]; then
    echo "{\"platform\":\"github\",\"method\":\"${method}\"}"
  else
    printf 'GitHub auth: %s\n' "${method}"
    if [[ "${method}" == "none" ]] || [[ "${GUIDE}" == "true" ]]; then
      print_github_guide
    fi
  fi
}

print_github_guide() {
  cat <<EOF

$(print_banner "GitHub authentication setup")

Recommended: GitHub CLI (OAuth, secure)
  gh auth login
  # Follow interactive prompts; token stored in OS keychain.

Alternative 1: Fine-grained PAT (in env var)
  1. Create PAT at https://github.com/settings/tokens?type=beta
     Required: Contents R/W, Issues R/W, Pull Requests R/W
  2. macOS Keychain:
     security add-generic-password -a github -s ghtoken -w "<your-PAT>"
  3. Linux (libsecret):
     secret-tool store --label="GitHub PAT" service ghtoken
  4. Windows Credential Manager:
     cmdkey /generic:github /user:<your-PAT>

Alternative 2: SSH key
  1. Generate: ssh-keygen -t ed25519 -C "you@example.com"
  2. Add to GitHub: https://github.com/settings/keys
  3. Test: ssh -T git@github.com

NEVER:
  - echo "\$GH_TOKEN=xxx" >> ~/.zshrc  (leaks to AI agents)
  - Inline /git push --token ghp_xxx   (shell history)
  - Commit token to repo                (permanent leak)
EOF
}

# ----- Gitee auth -----
check_gitee() {
  local method="none"
  if has_cmd gitee && gitee auth status >/dev/null 2>&1; then
    method="gitee-cli"
  elif [[ -n "${GITEE_TOKEN:-}" ]]; then
    method="token"
  elif [[ -f "${HOME}/.ssh/id_ed25519" ]] || [[ -f "${HOME}/.ssh/id_rsa" ]]; then
    if ssh -T -o BatchMode=yes -o ConnectTimeout=5 git@gitee.com 2>&1 | grep -q "successfully authenticated\|Welcome to Gitee"; then
      method="ssh"
    fi
  fi

  if [[ "${JSON_OUT}" == "true" ]]; then
    echo "{\"platform\":\"gitee\",\"method\":\"${method}\"}"
  else
    printf 'Gitee auth: %s\n' "${method}"
    if [[ "${method}" == "none" ]] || [[ "${GUIDE}" == "true" ]]; then
      print_gitee_guide
    fi
  fi
}

print_gitee_guide() {
  cat <<EOF

$(print_banner "Gitee authentication setup")

Recommended: oschina/gitee-cli (OAuth-like)
  Install: https://gitee.com/oschina/gitee-cli (follow README)
  Then:    gitee auth login

Alternative 1: Personal Access Token (in env var)
  1. Create token at https://gitee.com/personal_access_tokens
     Minimum scopes: user_info, projects, pull_requests, issues
  2. macOS Keychain:
     security add-generic-password -a gitee -s giteetoken -w "<your-token>"
  3. Linux (libsecret):
     secret-tool store --label="Gitee Token" service giteetoken
  4. Windows Credential Manager:
     cmdkey /generic:gitee /user:<your-PAT>

Alternative 2: SSH key
  1. Generate: ssh-keygen -t ed25519 -C "you@example.com"
  2. Add to Gitee: https://gitee.com/profile/sshkeys
  3. Test: ssh -T git@gitee.com

NEVER:
  - echo "\$GITEE_TOKEN=xxx" >> ~/.zshrc
  - Inline /git push --token xxx
  - Commit token to repo
EOF
}

# ----- Main dispatch -----
case "${PLATFORM}" in
  github) check_github ;;
  gitee)  check_gitee  ;;
  no-remote|unknown|"")
    log_warn "Cannot detect platform: no remote configured or unrecognized URL"
    log_info "Run 'git remote add origin <url>' first, or specify --platform"
    print_github_guide
    echo ""
    print_gitee_guide
    ;;
  *) log_err "Unknown platform: ${PLATFORM}" ;;
esac