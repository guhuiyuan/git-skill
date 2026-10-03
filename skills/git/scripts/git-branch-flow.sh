#!/usr/bin/env bash
#
# git-branch-flow.sh — Branch operations wrapper.
#
# Subcommands:
#   new <name>            Create new branch (from current HEAD)
#   switch <name>         Switch to existing branch
#   list                  List branches
#   delete <name>         Delete branch (asks confirmation for unmerged)
#   rename <old> <new>    Rename branch

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

print_usage() {
  cat <<EOF
Usage: git-branch-flow.sh <subcommand> [args]

Subcommands:
  new <name>            Create new branch (use conventional naming: feat/fix/chore)
  switch <name>         Switch to existing branch
  list                  List all branches (current marked with *)
  delete <name>         Delete branch (asks confirmation if unmerged)
  rename <old> <new>    Rename branch

Examples:
  git-branch-flow.sh new feat/user-auth
  git-branch-flow.sh switch main
  git-branch-flow.sh delete feat/old-feature
EOF
}

SUBCMD="${1:-}"
shift || true

case "${SUBCMD}" in
  new)
    name="${1:-}"
    [[ -z "${name}" ]] && log_err "Branch name required"
    require_git_repo
    log_info "Creating branch: ${name}"
    run_cmd git switch -c "${name}"
    log_ok "Created and switched to ${name}"
    ;;
  switch)
    name="${1:-}"
    [[ -z "${name}" ]] && log_err "Branch name required"
    require_git_repo
    log_info "Switching to: ${name}"
    run_cmd git switch "${name}"
    ;;
  list)
    require_git_repo
    git branch -a --format='%(if)%(HEAD)%(then)* %(else)  %(end)%(refname:short) %(upstream:track)' 2>/dev/null || git branch -a
    ;;
  delete)
    name="${1:-}"
    [[ -z "${name}" ]] && log_err "Branch name required"
    require_git_repo
    # Check if merged
    if ! git rev-parse --verify "${name}" >/dev/null 2>&1; then
      log_err "Branch '${name}' does not exist"
    fi

    is_merged=false
    if git merge-base --is-ancestor "${name}" HEAD 2>/dev/null; then
      is_merged=true
    fi

    if [[ "${is_merged}" == "false" ]]; then
      log_warn "Branch '${name}' is NOT merged into current HEAD."
      log_warn "Deleting it may lose commits."
      read -r -p "Force delete? [y/N]: " confirm
      case "${confirm}" in
        y|Y|yes|YES) run_cmd git branch -D "${name}" ;;
        *) log_err "Cancelled" ;;
      esac
    else
      log_info "Branch '${name}' is merged. Safe to delete."
      run_cmd git branch -d "${name}"
    fi
    ;;
  rename)
    old="${1:-}"; new="${2:-}"
    [[ -z "${old}" || -z "${new}" ]] && log_err "Both old and new branch names required"
    require_git_repo
    run_cmd git branch -m "${old}" "${new}"
    ;;
  ""|-h|--help)
    print_usage
    ;;
  *)
    log_err "Unknown subcommand: ${SUBCMD}. Use --help."
    ;;
esac