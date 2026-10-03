#!/usr/bin/env bash
#
# _platform/gitee.sh — Gitee adapter using oschina/gitee-cli (preferred) or REST API.
#
# Sourced by business scripts. Provides parallel interface to github.sh:
#   gitee_create_repo <name> <private|public> [description]
#   gitee_create_issue <title> <body>
#   gitee_list_issues [state] [limit]
#   gitee_create_pr <base> <title> <body>
#   gitee_list_prs [state] [limit]
#   gitee_check_auth
#
# API differences from GitHub (see references/platform-gitee.md):
#   - Auth uses ?access_token=<TOKEN> query param (NOT header)
#   - Default branch is master (NOT main)
#   - PR resource is /pulls (NOT /pull_request)
#   - REST only (no GraphQL)

set -euo pipefail
IFS=$'\n\t'

if ! declare -f log_info >/dev/null 2>&1; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
  # shellcheck source=../_lib/common.sh
  source "${SCRIPT_DIR}/../_lib/common.sh"
fi

# ----- Auth check -----
gitee_check_auth() {
  if has_cmd gitee && gitee auth status >/dev/null 2>&1; then
    echo "gitee-cli"
    return 0
  fi
  if [[ -n "${GITEE_TOKEN:-}" ]]; then
    echo "token"
    return 0
  fi
  echo "none"
  return 1
}

# ----- Internal REST helper (Gitee style: token as query param) -----
_gitee_rest() {
  # _gitee_rest <method> <path> [data]
  local method="$1" path="$2" data="${3:-}"
  if [[ -z "${GITEE_TOKEN:-}" ]]; then
    log_err "GITEE_TOKEN not set. Run 'gitee auth login' or set GITEE_TOKEN."
  fi
  local url="https://gitee.com/api/v5${path}"
  # Append access_token (Gitee uses query param, NOT header)
  if [[ "${url}" == *"?"* ]]; then
    url="${url}&access_token=${GITEE_TOKEN}"
  else
    url="${url}?access_token=${GITEE_TOKEN}"
  fi
  if [[ -n "${data}" ]]; then
    curl -fsSL -X "${method}" \
      -H "Content-Type: application/json;charset=UTF-8" \
      "${url}" -d "${data}"
  else
    curl -fsSL -X "${method}" \
      -H "Content-Type: application/json;charset=UTF-8" \
      "${url}"
  fi
}

# ----- Repo creation -----
gitee_create_repo() {
  # gitee_create_repo <name> <public|private> [description]
  local name="$1" visibility="$2" description="${3:-}"

  local is_private="false"
  [[ "${visibility}" == "private" ]] && is_private="true"

  if has_cmd gitee && gitee auth status >/dev/null 2>&1; then
    log_info "Creating repo via gitee CLI: ${name}"
    local gitee_args=(--name "${name}" --public)
    [[ "${visibility}" == "private" ]] && gitee_args=(--name "${name}" --private)
    [[ -n "${description}" ]] && gitee_args+=(--description "${description}")

    if gitee repo create "${gitee_args[@]}"; then
      log_ok "Repo created on Gitee: ${name}"
      return 0
    fi
    log_warn "gitee CLI failed; falling back to REST"
  fi

  # REST API fallback
  log_info "Creating repo via REST API: ${name}"
  local payload
  if [[ -n "${description}" ]]; then
    payload=$(printf '{"name":"%s","private":%s,"description":"%s","auto_init":false,"has_issues":true,"has_wiki":true}' \
      "${name}" "${is_private}" "${description}")
  else
    payload=$(printf '{"name":"%s","private":%s,"auto_init":false,"has_issues":true,"has_wiki":true}' \
      "${name}" "${is_private}")
  fi

  _gitee_rest POST "/user/repos" "${payload}" >/dev/null && log_ok "Repo created on Gitee: ${name}" || log_err "Failed to create repo"
}

# ----- Issue creation -----
gitee_create_issue() {
  # gitee_create_issue <title> <body>
  local title="$1" body="${2:-}"

  if has_cmd gitee && gitee auth status >/dev/null 2>&1; then
    log_info "Creating issue via gitee CLI: ${title}"
    local args=(--title "${title}")
    [[ -n "${body}" ]] && args+=(--body "${body}")
    gitee issue create "${args[@]}"
    return 0
  fi

  # REST fallback
  log_warn "gitee CLI not available; use GITEE_TOKEN + REST"
  log_err "REST fallback for issue creation not yet implemented; install gitee CLI"
}

gitee_list_issues() {
  local state="${1:-open}" limit="${2:-30}"
  if has_cmd gitee && gitee auth status >/dev/null 2>&1; then
    gitee issue list --state "${state}" --limit "${limit}"
    return 0
  fi
  log_err "gitee CLI not available; cannot list issues"
}

# ----- PR creation -----
gitee_create_pr() {
  # gitee_create_pr <base> <title> <body>
  local base="$1" title="$2" body="${3:-}"

  # Gitee default is master, not main
  [[ -z "${base}" ]] && base="master"

  if has_cmd gitee && gitee auth status >/dev/null 2>&1; then
    log_info "Creating PR via gitee CLI: ${title}"
    local args=(--base "${base}" --title "${title}")
    [[ -n "${body}" ]] && args+=(--body "${body}")
    gitee pr create "${args[@]}"
    return 0
  fi
  log_err "gitee CLI not available; cannot create PR"
}

gitee_list_prs() {
  local state="${1:-open}" limit="${2:-30}"
  if has_cmd gitee && gitee auth status >/dev/null 2>&1; then
    gitee pr list --state "${state}" --limit "${limit}"
    return 0
  fi
  log_err "gitee CLI not available; cannot list PRs"
}