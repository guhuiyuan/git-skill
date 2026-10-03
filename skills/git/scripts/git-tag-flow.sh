#!/usr/bin/env bash
#
# git-tag-flow.sh — Tag operations.

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

print_usage() {
  cat <<EOF
Usage: git-tag-flow.sh <subcommand> [args]

Subcommands:
  list                    List all tags
  <name>                  Create lightweight tag at HEAD
  <name> -m "msg"         Create annotated tag at HEAD
  delete <name>           Delete local tag
  push <remote> <name>    Push tag to remote
EOF
}

SUBCMD="${1:-}"
shift || true

require_git_repo

case "${SUBCMD}" in
  list)
    git tag --sort=-v:refname
    ;;
  "")
    print_usage
    ;;
  push)
    remote="${1:-}"; name="${2:-}"
    [[ -z "${remote}" || -z "${name}" ]] && log_err "Both remote and tag name required"
    run_cmd git push "${remote}" "${name}"
    ;;
  delete|-d)
    name="${1:-}"
    [[ -z "${name}" ]] && log_err "Tag name required"
    log_warn "Deleting tag '${name}'"
    run_cmd git tag -d "${name}"
    ;;
  *)
    # Treat as new tag
    if [[ "${1:-}" == "-m" ]] || [[ "${1:-}" == "-a" ]]; then
      log_err "Tag creation syntax: git-tag-flow.sh <name> [-m 'msg']"
    fi
    name="${SUBCMD}"
    msg=""
    if [[ "${1:-}" == "-m" ]]; then
      msg="${2:-}"
      [[ -z "${msg}" ]] && log_err "Empty message after -m"
    fi
    if [[ -n "${msg}" ]]; then
      run_cmd git tag -a "${name}" -m "${msg}"
    else
      run_cmd git tag "${name}"
    fi
    log_ok "Tag created: ${name}"
    ;;
esac