#!/usr/bin/env bash
#
# _platform/github.sh — GitHub adapter using gh CLI (preferred) or REST API.
#
# Sourced by business scripts. Provides:
#   gh_create_repo <name> <private|public> [description] [org]
#   gh_create_issue <title> <body> [--labels x,y]
#   gh_list_issues [state] [limit]
#   gh_create_pr <base> <title> <body> [--draft]
#   gh_list_prs [state] [limit]
#   gh_check_auth
#
# Falls back to REST API when gh is not available.

set -euo pipefail
IFS=$'\n\t'

# Source common library if not already
if ! declare -f log_info >/dev/null 2>&1; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
  # shellcheck source=../_lib/common.sh
  source "${SCRIPT_DIR}/../_lib/common.sh"
fi

# ----- Auth check -----
gh_check_auth() {
  if has_cmd gh && gh auth status >/dev/null 2>&1; then
    echo "gh"
    return 0
  fi
  if [[ -n "${GH_TOKEN:-}" ]]; then
    echo "token"
    return 0
  fi
  echo "none"
  return 1
}

# ----- Internal REST helper -----
_gh_rest() {
  # _gh_rest <method> <path> [data]
  local method="$1" path="$2" data="${3:-}"
  if [[ -z "${GH_TOKEN:-}" ]]; then
    log_err "GH_TOKEN not set. Run 'gh auth login' or set GH_TOKEN."
  fi
  local url="https://api.github.com${path}"
  if [[ -n "${data}" ]]; then
    curl -fsSL -X "${method}" \
      -H "Authorization: token ${GH_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "${url}" -d "${data}"
  else
    curl -fsSL -X "${method}" \
      -H "Authorization: token ${GH_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "${url}"
  fi
}

# ----- Repo creation -----
gh_create_repo() {
  # gh_create_repo <name> <public|private> [description] [org]
  local name="$1" visibility="$2" description="${3:-}" org="${4:-}"

  local visibility_flag="--public"
  [[ "${visibility}" == "private" ]] && visibility_flag="--private"

  if has_cmd gh && gh auth status >/dev/null 2>&1; then
    local gh_args=("${visibility_flag}" --source=. --remote=origin --push=false --confirm)
    if [[ -n "${description}" ]]; then gh_args+=(--description "${description}"); fi
    if [[ -n "${org}" ]]; then gh_args+=(--add-remote --remote-name=origin); fi

    log_info "Creating repo via gh CLI: ${name}"
    if gh repo create "${org:+${org}/}${name}" "${gh_args[@]}"; then
      log_ok "Repo created: $([[ -n "${org}" ]] && echo "${org}/" || echo "")${name}"
      return 0
    fi
    log_warn "gh repo create failed; falling back to REST"
  fi

  # REST API fallback
  log_info "Creating repo via REST API: ${name}"
  local payload
  if [[ -n "${description}" ]]; then
    payload=$(printf '{"name":"%s","private":%s,"description":"%s","auto_init":false}' \
      "${name}" "$([[ "${visibility}" == "private" ]] && echo true || echo false)" "${description}")
  else
    payload=$(printf '{"name":"%s","private":%s,"auto_init":false}' \
      "${name}" "$([[ "${visibility}" == "private" ]] && echo true || echo false)")
  fi

  local endpoint="/user/repos"
  [[ -n "${org}" ]] && endpoint="/orgs/${org}/repos"

  _gh_rest POST "${endpoint}" "${payload}" | grep -q "\"name\":\"${name}\"" && log_ok "Repo created" || log_err "Failed to create repo"
}

# ----- Issue creation -----
gh_create_issue() {
  # gh_create_issue <title> <body>
  local title="$1" body="${2:-}"

  if has_cmd gh && gh auth status >/dev/null 2>&1; then
    log_info "Creating issue via gh CLI: ${title}"
    if [[ -n "${body}" ]]; then
      gh issue create --title "${title}" --body "${body}" --repo "$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo .)"
    else
      gh issue create --title "${title}" --repo "$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo .)"
    fi
    return 0
  fi

  log_warn "gh not available; use GITHUB_TOKEN + REST to create issues"
  log_err "REST fallback not yet implemented; install gh CLI"
}

gh_list_issues() {
  # gh_list_issues [state] [limit]
  local state="${1:-open}" limit="${2:-30}"
  if has_cmd gh && gh auth status >/dev/null 2>&1; then
    gh issue list --state "${state}" --limit "${limit}"
    return 0
  fi
  log_err "gh CLI not available; cannot list issues"
}

# ----- PR creation -----
gh_create_pr() {
  # gh_create_pr <base> <title> <body> [draft]
  local base="$1" title="$2" body="${3:-}" draft="${5:-false}"

  if has_cmd gh && gh auth status >/dev/null 2>&1; then
    local args=(--base "${base}" --title "${title}")
    [[ -n "${body}" ]] && args+=(--body "${body}")
    [[ "${draft}" == "true" ]] && args+=(--draft)
    log_info "Creating PR via gh CLI: ${title}"
    gh pr create "${args[@]}"
    return 0
  fi
  log_err "gh CLI not available; cannot create PR"
}

gh_list_prs() {
  # gh_list_prs [state] [limit]
  local state="${1:-open}" limit="${2:-30}"
  if has_cmd gh && gh auth status >/dev/null 2>&1; then
    gh pr list --state "${state}" --limit "${limit}"
    return 0
  fi
  log_err "gh CLI not available; cannot list PRs"
}