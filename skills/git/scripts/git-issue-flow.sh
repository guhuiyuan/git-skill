#!/usr/bin/env bash
#
# git-issue-flow.sh — Create / list / view issues on GitHub or Gitee.

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

# Detect platform
PLATFORM="$("${SCRIPT_DIR}/platform-detect.sh")"

# Source appropriate adapter
case "${PLATFORM}" in
  github)
    # shellcheck source=_platform/github.sh
    source "${SCRIPT_DIR}/_platform/github.sh"
    cmd="gh"
    ;;
  gitee)
    # shellcheck source=_platform/gitee.sh
    source "${SCRIPT_DIR}/_platform/gitee.sh"
    cmd="gitee"
    ;;
  no-remote|unknown)
    log_err "No remote or unknown platform. Run 'git remote add origin <url>' first."
    ;;
  *)
    log_err "Platform not supported: ${PLATFORM}"
    ;;
esac

print_usage() {
  cat <<EOF
Usage: git-issue-flow.sh <subcommand> [args]

Subcommands:
  new --title "x" [--body "y"] [--labels a,b]
  list [--state open|closed|all] [--limit N]
  view <number>
EOF
}

SUBCMD="${1:-}"
shift || true

case "${SUBCMD}" in
  new)
    title=""
    body=""
    labels=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --title)  title="$2"; shift 2 ;;
        --body)   body="$2"; shift 2 ;;
        --labels) labels="$2"; shift 2 ;;
        *) log_err "Unknown flag: $1" ;;
      esac
    done

    [[ -z "${title}" ]] && log_err "--title required"

    case "${PLATFORM}" in
      github)
        args=(--title "${title}")
        [[ -n "${body}" ]]   && args+=(--body "${body}")
        [[ -n "${labels}" ]] && args+=(--label "${labels}")
        if has_cmd gh && gh auth status >/dev/null 2>&1; then
          gh issue create "${args[@]}"
        else
          log_err "gh CLI required for issues. Run 'gh auth login'."
        fi
        ;;
      gitee)
        args=(--title "${title}")
        [[ -n "${body}" ]] && args+=(--body "${body}")
        if has_cmd gitee && gitee auth status >/dev/null 2>&1; then
          gitee issue create "${args[@]}"
        else
          log_err "gitee CLI required. Install from gitee.com/oschina/gitee-cli."
        fi
        ;;
    esac
    ;;
  list)
    state="open"
    limit="30"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --state) state="$2"; shift 2 ;;
        --limit) limit="$2"; shift 2 ;;
        *) log_err "Unknown flag: $1" ;;
      esac
    done

    case "${PLATFORM}" in
      github)
        has_cmd gh && gh auth status >/dev/null 2>&1 && gh issue list --state "${state}" --limit "${limit}" || log_err "gh CLI required"
        ;;
      gitee)
        has_cmd gitee && gitee auth status >/dev/null 2>&1 && gitee issue list --state "${state}" --limit "${limit}" || log_err "gitee CLI required"
        ;;
    esac
    ;;
  view)
    num="${1:-}"
    [[ -z "${num}" ]] && log_err "Issue number required"
    case "${PLATFORM}" in
      github)
        has_cmd gh && gh auth status >/dev/null 2>&1 && gh issue view "${num}" || log_err "gh CLI required"
        ;;
      gitee)
        has_cmd gitee && gitee auth status >/dev/null 2>&1 && gitee issue view "${num}" || log_err "gitee CLI required"
        ;;
    esac
    ;;
  "")
    print_usage
    ;;
  *)
    log_err "Unknown subcommand: ${SUBCMD}"
    ;;
esac