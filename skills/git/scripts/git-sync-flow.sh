#!/usr/bin/env bash
#
# git-sync-flow.sh — Pull with rebase (default) or plain fetch/pull.

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

print_usage() {
  cat <<EOF
Usage: git-sync-flow.sh [--fetch-only] [--no-rebase] [remote] [branch]

Sync with remote.

Default: git pull --rebase (clean linear history)
  --fetch-only   Only fetch, don't merge/rebase
  --no-rebase    Use plain git pull (merge)
EOF
}

FETCH_ONLY=false
USE_REBASE=true
REMOTE=""
BRANCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fetch-only) FETCH_ONLY=true; shift ;;
    --no-rebase)  USE_REBASE=false; shift ;;
    --help|-h)    print_usage; exit 0 ;;
    origin|upstream) REMOTE="$1"; shift ;;
    -*) log_err "Unknown flag: $1" ;;
    *)
      if [[ -z "${REMOTE}" ]]; then REMOTE="$1"; shift
      elif [[ -z "${BRANCH}" ]]; then BRANCH="$1"; shift
      else log_err "Unexpected: $1"; fi
      ;;
  esac
done

require_git_repo
REMOTE="${REMOTE:-origin}"

if [[ "${FETCH_ONLY}" == "true" ]]; then
  log_info "Fetching from ${REMOTE}..."
  run_cmd git fetch "${REMOTE}"
  log_ok "Fetch complete."
  exit 0
fi

if [[ -z "${BRANCH}" ]]; then
  BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo "")"
fi

log_info "Pulling ${BRANCH} from ${REMOTE}..."

if [[ "${USE_REBASE}" == "true" ]]; then
  if [[ -n "${BRANCH}" ]]; then
    run_cmd git pull --rebase "${REMOTE}" "${BRANCH}"
  else
    run_cmd git pull --rebase "${REMOTE}"
  fi
else
  if [[ -n "${BRANCH}" ]]; then
    run_cmd git pull "${REMOTE}" "${BRANCH}"
  else
    run_cmd git pull "${REMOTE}"
  fi
fi

log_ok "Sync complete."