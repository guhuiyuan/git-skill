#!/usr/bin/env bash
#
# precommit-guard.sh — Installable as a git pre-commit hook.
#
# Two ways to use:
#   A. Install per-repo: git config core.hooksPath /path/to/skill/scripts
#   B. Symlink: ln -s /path/to/skill/scripts/precommit-guard.sh .git/hooks/pre-commit
#
# Behavior: blocks commit if CRITICAL secrets found in staged diff.

set -euo pipefail
IFS=$'\n\t'

# Resolve skill directory (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CHECK_SECRETS="${SCRIPT_DIR}/check-secrets.sh"

# Source common lib for log functions
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

log_info "git-skill pre-commit guard: scanning staged changes..."

if [[ ! -x "${CHECK_SECRETS}" ]]; then
  log_err "check-secrets.sh not found at ${CHECK_SECRETS}"
fi

# Run scan; exit 1 if CRITICAL found
if ! "${CHECK_SECRETS}" --staged --severity critical >/dev/null 2>&1; then
  log_err "
🚫 Commit BLOCKED: secrets detected in staged changes.

Run /git scan (or check-secrets.sh --staged) to see details.

Fix options:
  1. Add the file to .gitignore:  echo 'file' >> .gitignore
  2. Remove from staging:         git reset HEAD <file>
  3. If secret is real: ROTATE IT IMMEDIATELY (don't commit even with bypass)

To bypass (NOT recommended, CRITICAL cannot be bypassed):
  - HIGH findings: git commit --no-verify (still scanned by skill flow)
"
fi

# Warn on HIGH (allow by default)
if ! "${CHECK_SECRETS}" --staged --severity high >/dev/null 2>&1; then
  log_warn "HIGH severity findings detected. Continuing (use --no-verify to skip)."
fi

exit 0