#!/usr/bin/env bash
#
# git-merge-flow.sh — Merge or rebase with conflict guidance.

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

print_usage() {
  cat <<EOF
Usage: git-merge-flow.sh merge <branch> [--no-ff] [--squash]
       git-merge-flow.sh rebase <upstream> [--interactive|-i]

Subcommands:
  merge <branch>          Merge branch into current
  rebase <upstream>       Rebase current onto upstream
EOF
}

SUBCMD="${1:-}"
shift || true

require_git_repo

case "${SUBCMD}" in
  merge)
    target="${1:-}"
    [[ -z "${target}" ]] && log_err "Target branch required"
    shift || true
    args=("$@")

    log_info "Merging ${target} into $(git symbolic-ref --short HEAD)..."
    if run_cmd git merge "${target}" "${args[@]}"; then
      log_ok "Merged successfully."
    else
      log_warn "Merge conflicts detected."
      log_info "Conflicted files:"
      git diff --name-only --diff-filter=U | sed 's/^/  /'
      log_info ""
      log_info "Resolve by:"
      log_info "  1. Edit each file (look for <<<<<<< markers)"
      log_info "  2. git add <resolved-file>"
      log_info "  3. git merge --continue  (or  git commit  if no --no-ff flag)"
      log_info ""
      log_info "Abort:  git merge --abort"
      exit 2
    fi
    ;;
  rebase)
    upstream="${1:-}"
    [[ -z "${upstream}" ]] && log_err "Upstream branch required"
    shift || true
    log_info "Rebasing current onto ${upstream}..."
    if run_cmd git rebase "${upstream}" "$@"; then
      log_ok "Rebased successfully."
    else
      log_warn "Rebase conflicts detected."
      log_info "Conflicted files:"
      git diff --name-only --diff-filter=U | sed 's/^/  /'
      log_info ""
      log_info "Resolve by:"
      log_info "  1. Edit each file (look for <<<<<<< markers)"
      log_info "  2. git add <resolved-file>"
      log_info "  3. git rebase --continue"
      log_info ""
      log_info "Abort:  git rebase --abort"
      exit 2
    fi
    ;;
  "")
    print_usage
    ;;
  *)
    log_err "Unknown subcommand: ${SUBCMD}."
    ;;
esac