#!/usr/bin/env bash
#
# git-stash-flow.sh — Stash operations.

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

print_usage() {
  cat <<EOF
Usage: git-stash-flow.sh <subcommand> [args]

Subcommands:
  push [-m "msg"]         Stash current changes
  pop                     Pop most recent stash
  list                    List all stashes
  apply <n>               Apply stash n (default 0)
  drop <n>                Drop stash n (with confirmation)
EOF
}

SUBCMD="${1:-}"
shift || true

require_git_repo

case "${SUBCMD}" in
  push)
    msg=""
    if [[ "${1:-}" == "-m" ]]; then
      msg="${2:-}"
    fi
    if [[ -n "${msg}" ]]; then
      run_cmd git stash push -m "${msg}"
    else
      run_cmd git stash push
    fi
    ;;
  pop)
    log_info "Restoring most recent stash..."
    run_cmd git stash pop
    ;;
  list)
    git stash list
    ;;
  apply)
    n="${1:-0}"
    run_cmd git stash apply "stash@{${n}}"
    ;;
  drop)
    n="${1:-0}"
    log_warn "Dropping stash@{${n}}"
    read -r -p "Are you sure? [y/N]: " confirm
    case "${confirm}" in
      y|Y|yes|YES) run_cmd git stash drop "stash@{${n}}" ;;
      *) log_err "Cancelled" ;;
    esac
    ;;
  "")
    # Default: list stashes
    git stash list
    ;;
  *)
    log_err "Unknown subcommand: ${SUBCMD}. Use --help."
    ;;
esac