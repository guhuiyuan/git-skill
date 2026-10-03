#!/usr/bin/env bash
#
# git-push-flow.sh — Push with integrated secret scanning (defense in depth).
#
# Even though /git commit already scans, this re-scans on push to defend
# against `git commit --amend` after the fact.

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

print_usage() {
  cat <<EOF
Usage: git-push-flow.sh [remote] [branch] [--set-upstream|-u] [--force] [--force-allow-high]

Push local commits to remote with secret scanning.

Options:
  remote                 Remote name (default: origin)
  branch                 Branch name (default: current)
  -u, --set-upstream     Set upstream
  --force                Force push (with caution; will prompt)
  --force-allow-high     Bypass HIGH secret findings
  --dry-run              Show what would be done
  --help, -h             Show this help
EOF
}

# ----- Args -----
REMOTE=""
BRANCH=""
SET_UPSTREAM=false
FORCE_PUSH=false
FORCE_ALLOW_HIGH=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--set-upstream) SET_UPSTREAM=true; shift ;;
    --force)           FORCE_PUSH=true; shift ;;
    --force-allow-high) FORCE_ALLOW_HIGH=true; shift ;;
    --dry-run)         DRY_RUN=true; shift ;;
    --help|-h)         print_usage; exit 0 ;;
    origin|upstream)   REMOTE="$1"; shift ;;
    -*)                log_err "Unknown flag: $1" ;;
    *)
      if [[ -z "${REMOTE}" ]]; then REMOTE="$1"; shift
      elif [[ -z "${BRANCH}" ]]; then BRANCH="$1"; shift
      else log_err "Unexpected argument: $1"; fi
      ;;
  esac
done

# ----- Preflight -----
require_git_repo
REMOTE="${REMOTE:-origin}"

# Default branch = current
if [[ -z "${BRANCH}" ]]; then
  BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo HEAD)"
fi

# Confirm force push (destructive)
if [[ "${FORCE_PUSH}" == "true" ]]; then
  log_warn "⚠️  Force push will rewrite remote history!"
  log_warn "  Branch: ${REMOTE}/${BRANCH}"
  read -r -p "Continue? [y/N]: " confirm
  case "${confirm}" in
    y|Y|yes|YES) log_info "Force push confirmed" ;;
    *) log_err "Cancelled" ;;
  esac
fi

# ----- Secret scan (defense in depth) -----
SCAN_ARGS=(--staged)
[[ "${FORCE_ALLOW_HIGH}" == "true" ]] && SCAN_ARGS+=(--force-allow-high)

if ! git diff --cached --quiet; then
  log_info "Re-scanning staged changes for secrets..."
  if ! "${SCRIPT_DIR}/check-secrets.sh" "${SCAN_ARGS[@]}"; then
    rc=$?
    case $rc in
      1) log_err "CRITICAL secrets detected. Push blocked." ;;
      2) log_err "HIGH secrets detected. Use --force-allow-high to override." ;;
    esac
  fi
fi

# Check if there are unpushed commits that haven't been scanned recently
LOCAL_COMMITS="$(git rev-list --count "${REMOTE}/${BRANCH}..HEAD" 2>/dev/null || echo 0)"
if [[ "${LOCAL_COMMITS}" -gt 0 ]]; then
  log_info "Found ${LOCAL_COMMITS} unpushed commit(s). Quick scan of recent commits..."

  # Scan recent commits for known secret patterns (last 10)
  recent_diff="$(git log -p --max-count=10 "${REMOTE}/${BRANCH}..HEAD" 2>/dev/null || echo "")"
  if [[ -n "${recent_diff}" ]]; then
    if echo "${recent_diff}" | grep -qE '(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|sk-[A-Za-z0-9]{20,}|sk-ant-[A-Za-z0-9_-]{40,})'; then
      log_err "Potential secrets found in unpushed commits. Use git filter-repo to clean (see references/workflows.md)"
    fi
  fi
fi

# ----- Push -----
PUSH_ARGS=()
[[ "${SET_UPSTREAM}" == "true" ]] && PUSH_ARGS+=(-u)
[[ "${FORCE_PUSH}" == "true" ]]   && PUSH_ARGS+=(--force)
PUSH_ARGS+=("${REMOTE}" "${BRANCH}")

run_cmd git push "${PUSH_ARGS[@]}"

log_ok "Pushed ${BRANCH} to ${REMOTE}."
exit 0