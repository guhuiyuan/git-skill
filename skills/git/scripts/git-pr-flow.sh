#!/usr/bin/env bash
#
# git-pr-flow.sh — Create / list / view PRs (GitHub) or Pull Requests (Gitee).

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

PLATFORM="$("${SCRIPT_DIR}/platform-detect.sh")"

case "${PLATFORM}" in
  github) source "${SCRIPT_DIR}/_platform/github.sh" ;;
  gitee)  source "${SCRIPT_DIR}/_platform/gitee.sh" ;;
  no-remote|unknown) log_err "No remote or unknown platform. Add origin first." ;;
  *) log_err "Platform not supported: ${PLATFORM}" ;;
esac

print_usage() {
  cat <<EOF
Usage: git-pr-flow.sh <subcommand> [args]

Subcommands:
  new --base <branch> --title "x" [--body "y"] [--draft]
  list [--state open|closed|merged|all] [--limit N]
  view <number>
  checks <number>      View CI checks
EOF
}

SUBCMD="${1:-}"
shift || true

case "${SUBCMD}" in
  new)
    base=""
    title=""
    body=""
    draft=false
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --base)   base="$2"; shift 2 ;;
        --title)  title="$2"; shift 2 ;;
        --body)   body="$2"; shift 2 ;;
        --draft)  draft=true; shift ;;
        *) log_err "Unknown flag: $1" ;;
      esac
    done

    [[ -z "${title}" ]] && log_err "--title required"
    # Default base: Gitee uses master, GitHub uses main
    if [[ -z "${base}" ]]; then
      case "${PLATFORM}" in
        github) base="main" ;;
        gitee)  base="master" ;;
      esac
    fi

    case "${PLATFORM}" in
      github)
        args=(--base "${base}" --title "${title}")
        [[ -n "${body}" ]] && args+=(--body "${body}")
        [[ "${draft}" == "true" ]] && args+=(--draft)
        has_cmd gh && gh auth status >/dev/null 2>&1 && gh pr create "${args[@]}" || log_err "gh CLI required"
        ;;
      gitee)
        args=(--base "${base}" --title "${title}")
        [[ -n "${body}" ]] && args+=(--body "${body}")
        has_cmd gitee && gitee auth status >/dev/null 2>&1 && gitee pr create "${args[@]}" || log_err "gitee CLI required"
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
        has_cmd gh && gh auth status >/dev/null 2>&1 && gh pr list --state "${state}" --limit "${limit}" || log_err "gh CLI required"
        ;;
      gitee)
        has_cmd gitee && gitee auth status >/dev/null 2>&1 && gitee pr list --state "${state}" --limit "${limit}" || log_err "gitee CLI required"
        ;;
    esac
    ;;
  view|checks)
    cmd="${SUBCMD}"
    num="${1:-}"
    [[ -z "${num}" ]] && log_err "PR number required"
    case "${PLATFORM}" in
      github)
        if [[ "${cmd}" == "checks" ]]; then
          has_cmd gh && gh auth status >/dev/null 2>&1 && gh pr checks "${num}" || log_err "gh CLI required"
        else
          has_cmd gh && gh auth status >/dev/null 2>&1 && gh pr view "${num}" || log_err "gh CLI required"
        fi
        ;;
      gitee)
        log_err "Gitee CLI does not have '${cmd}' subcommand; use 'gitee pr view ${num}' directly"
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