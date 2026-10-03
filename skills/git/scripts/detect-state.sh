#!/usr/bin/env bash
#
# detect-state.sh — Inspect current working directory git state.
#
# Output (human-readable):
#   Git repo: yes/no
#   Branch:        <- name
#   Default branch: main/master
#   Remote origin: <url> / none
#   Platform: github | gitee | unknown
#   Auth method:   gh | gitee | ssh | token | none
#   Uncommitted:   yes/no
#
# Output (--json):
#   {"is_repo":true,"branch":"...","default_branch":"...","remote":"...",
#    "platform":"github","auth":"gh","dirty":false}

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

parse_common_flags "$@"

# ----- Detect -----
is_repo=false
branch=""
default_branch=""
remote_url=""
platform="unknown"
auth_method="none"
dirty=false

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  is_repo=true
  branch="$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "")"
  default_branch="$(git remote show origin 2>/dev/null | sed -n 's/^.*HEAD branch: //p' || echo "")"
  if [[ -z "${default_branch}" ]]; then
    # Fallback: try symbolic-ref or assume main
    default_branch="$(git config --get init.defaultBranch 2>/dev/null || echo main)"
  fi
  remote_url="$(git remote get-url origin 2>/dev/null || echo "")"

  # Detect platform
  case "${remote_url}" in
    *github.com*|*githubusercontent*|*ghe.com*) platform="github" ;;
    *gitee.com*)                              platform="gitee" ;;
    *)                                        platform="unknown" ;;
  esac

  # Detect auth method
  if [[ "${platform}" == "github" ]]; then
    if has_cmd gh && gh auth status >/dev/null 2>&1; then
      auth_method="gh"
    elif [[ -n "${GH_TOKEN:-}" ]]; then
      auth_method="token"
    elif [[ -n "${remote_url}" ]] && [[ "${remote_url}" == git@* ]]; then
      auth_method="ssh"
    fi
  elif [[ "${platform}" == "gitee" ]]; then
    if has_cmd gitee && gitee auth status >/dev/null 2>&1; then
      auth_method="gitee"
    elif [[ -n "${GITEE_TOKEN:-}" ]]; then
      auth_method="token"
    elif [[ -n "${remote_url}" ]] && [[ "${remote_url}" == git@* ]]; then
      auth_method="ssh"
    fi
  fi

  # Check dirty
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    dirty=true
  fi
fi

# ----- Output -----
if is_json_mode; then
  cat <<EOF
{"is_repo":${is_repo},"branch":"${branch}","default_branch":"${default_branch}","remote":"${remote_url}","platform":"${platform}","auth":"${auth_method}","dirty":${dirty}}
EOF
else
  printf 'Git repo: %s\n' "${is_repo}"
  printf 'Branch: %s\n' "${branch:-<none>}"
  printf 'Default branch: %s\n' "${default_branch:-<unknown>}"
  printf 'Remote origin: %s\n' "${remote_url:-<none>}"
  printf 'Platform: %s\n' "${platform}"
  printf 'Auth method: %s\n' "${auth_method}"
  printf 'Uncommitted changes: %s\n' "${dirty}"
fi

exit 0