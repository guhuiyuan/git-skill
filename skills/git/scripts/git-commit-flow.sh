#!/usr/bin/env bash
#
# git-commit-flow.sh — Commit with integrated secret scanning.
#
# Layered security:
#   1. check-secrets.sh --staged (mandatory)
#   2. If CRITICAL: block
#   3. If HIGH: block unless --force-allow-high
#   4. If LOW: warn, continue

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

print_usage() {
  cat <<EOF
Usage: git-commit-flow.sh [--message "msg"] [--amend] [--force-allow-high]

Commit staged changes with secret scanning.

Options:
  -m, --message MSG      Commit message (else opens editor or generates)
  --amend                Amend the previous commit
  --force-allow-high     Bypass HIGH secret findings
  --no-verify            Skip pre-commit hook (still scanned by skill flow)
  --dry-run              Show what would be done
  --help, -h             Show this help
EOF
}

# ----- Args -----
MSG=""
AMEND=""
FORCE_ALLOW_HIGH=false
NO_VERIFY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--message)   MSG="$2"; shift 2 ;;
    --amend)        AMEND="--amend"; shift ;;
    --force-allow-high) FORCE_ALLOW_HIGH=true; shift ;;
    --no-verify)    NO_VERIFY=true; shift ;;
    --dry-run)      DRY_RUN=true; shift ;;
    --help|-h)      print_usage; exit 0 ;;
    *) log_err "Unknown argument: $1 (use --help)" ;;
  esac
done

# ----- Preflight -----
require_git_repo

# Stage if nothing staged
if git diff --cached --quiet; then
  log_warn "Nothing staged. Auto-staging all tracked + modified files."
  git add -u
  if git diff --cached --quiet; then
    log_err "Nothing to commit (no changes)."
  fi
fi

# ----- Secret scan -----
SCAN_ARGS=(--staged)
[[ "${FORCE_ALLOW_HIGH}" == "true" ]] && SCAN_ARGS+=(--force-allow-high)

log_info "Scanning staged changes for secrets..."
if ! "${SCRIPT_DIR}/check-secrets.sh" "${SCAN_ARGS[@]}"; then
  rc=$?
  case $rc in
    1) log_err "CRITICAL secrets detected. Add to .gitignore, rotate, or use secret manager." ;;
    2) log_err "HIGH secrets detected. Use --force-allow-high to override (CRITICAL cannot be bypassed)." ;;
    *) log_err "Secret scan failed (exit $rc)." ;;
  esac
fi

# ----- Build commit command -----
COMMIT_ARGS=()
[[ -n "${MSG}" ]]            && COMMIT_ARGS+=(-m "${MSG}")
[[ -n "${AMEND}" ]]          && COMMIT_ARGS+=("${AMEND}")
[[ "${NO_VERIFY}" == "true" ]] && COMMIT_ARGS+=(--no-verify)

# If no message and not amend, use conventional commit prefix
if [[ -z "${MSG}" ]] && [[ -z "${AMEND}" ]]; then
  log_info "No message provided. Use conventional commit format: feat:/fix:/chore:/docs:/test:/refactor:"
  COMMIT_ARGS+=(--interactive 2>/dev/null || true)
  # Fall back to git's default behavior (opens editor)
fi

# ----- Commit -----
run_cmd git commit "${COMMIT_ARGS[@]}"

log_ok "Committed successfully."
exit 0