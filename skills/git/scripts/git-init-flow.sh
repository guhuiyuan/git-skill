#!/usr/bin/env bash
#
# git-init-flow.sh — Initialize current directory as git repository.
#
# Steps:
#   1. Detect current state (must not be a repo)
#   2. Ask default branch name (main/master)
#   3. git init -b <branch>
#   4. Detect language, generate .gitignore (if user agrees)
#   5. Optionally generate README and LICENSE
#   6. Initial add + commit

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

print_usage() {
  cat <<EOF
Usage: git-init-flow.sh [--branch NAME] [--no-gitignore] [--no-readme] [--no-license]

Initialize current directory as a git repository with optional scaffolding.

Options:
  --branch NAME    Default branch name (default: main)
  --no-gitignore   Skip .gitignore generation
  --no-readme      Skip README generation
  --no-license     Skip LICENSE generation
  --force-allow-high  Pass through to gitignore generator if it warns
  --dry-run        Show what would be done
  --help, -h       Show this help
EOF
}

# ----- Args -----
BRANCH=""
DO_GITIGNORE=true
DO_README=true
DO_LICENSE=true
FORCE_ALLOW_HIGH=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)            BRANCH="$2"; shift 2 ;;
    --no-gitignore)      DO_GITIGNORE=false; shift ;;
    --no-readme)         DO_README=false; shift ;;
    --no-license)        DO_LICENSE=false; shift ;;
    --force-allow-high)  FORCE_ALLOW_HIGH=true; shift ;;
    --dry-run)           DRY_RUN=true; shift ;;
    --help|-h)           print_usage; exit 0 ;;
    *) log_err "Unknown argument: $1 (use --help)" ;;
  esac
done

# ----- Preflight -----
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log_err "Already a git repository. Use /git status to view state."
fi

# Determine branch name
if [[ -z "${BRANCH}" ]]; then
  BRANCH="$(git config --get init.defaultBranch || echo main)"
fi

log_info "Initializing git repository with default branch: ${BRANCH}"

run_cmd git init -b "${BRANCH}"

# Configure user if not set
if [[ -z "$(git config user.name 2>/dev/null || echo)" ]]; then
  log_warn "user.name not configured. Set with: git config user.name \"Your Name\""
fi
if [[ -z "$(git config user.email 2>/dev/null || echo)" ]]; then
  log_warn "user.email not configured. Set with: git config user.email \"you@example.com\""
fi

# ----- Generate .gitignore -----
if [[ "${DO_GITIGNORE}" == "true" ]]; then
  if [[ -x "${SCRIPT_DIR}/generate-gitignore.sh" ]]; then
    log_info "Generating .gitignore (auto-detecting language)..."
    FORCE_ALLOW_HIGH="${FORCE_ALLOW_HIGH}" run_cmd "${SCRIPT_DIR}/generate-gitignore.sh" || log_warn ".gitignore generation skipped"
  fi
fi

# ----- Generate README -----
if [[ "${DO_README}" == "true" ]]; then
  log_info "README generation available via /git readme (interactive)"
fi

# ----- Generate LICENSE -----
if [[ "${DO_LICENSE}" == "true" ]]; then
  log_info "LICENSE generation available via /git license (interactive)"
fi

# ----- Initial commit -----
log_info "Creating initial commit..."
run_cmd git add .gitignore

# Allow empty commit if .gitignore was the only file
if git diff --cached --quiet; then
  log_warn "Nothing to commit (.gitignore may be empty or no language detected)"
  log_ok "Repository initialized at $(pwd)"
  exit 0
fi

run_cmd git commit -m "chore: initial commit (with .gitignore)"

log_ok "
✅ Repository initialized!
  Branch:    ${BRANCH}
  Path:      $(pwd)

Next steps:
  /git readme          Generate README
  /git license         Choose and generate LICENSE
  /git create-repo --platform github|gitee --name <name>   Create remote
  /git push -u origin ${BRANCH}    Push to remote
"
exit 0