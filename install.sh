#!/usr/bin/env bash
#
# install.sh — Deploy git-skill to ~/.claude/skills/git/
#
# Usage:
#   ./install.sh                  # Install to default location
#   SKILL_HOME=/path ./install.sh # Install to custom location
#
# Supports: macOS, Linux, Git Bash on Windows

set -euo pipefail
IFS=$'\n\t'

# ----- Constants -----
VERSION="1.0.0"
SKILL_NAME="git"

# ----- Resolve paths -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/skills/${SKILL_NAME}"
SKILL_HOME="${SKILL_HOME:-${HOME}/.claude/skills/${SKILL_NAME}}"

# ----- Color helpers -----
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_CYAN=$'\033[36m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
  C_RED=''; C_GREEN=''; C_YELLOW=''; C_CYAN=''; C_BOLD=''; C_RESET=''
fi

log()  { printf '%s[git-skill]%s %s\n' "${C_CYAN}" "${C_RESET}" "$*" >&2; }
ok()   { printf '%s[ok]%s %s\n' "${C_GREEN}" "${C_RESET}" "$*" >&2; }
warn() { printf '%s[warn]%s %s\n' "${C_YELLOW}" "${C_RESET}" "$*" >&2; }
err()  { printf '%s[error]%s %s\n' "${C_RED}" "${C_RESET}" "$*" >&2; }
need() { command -v "$1" >/dev/null 2>&1; }

# ----- Pre-flight -----
log "${C_BOLD}Git Skill installer v${VERSION}${C_RESET}"
log "Source: ${SRC_DIR}"
log "Target: ${SKILL_HOME}"
echo "" >&2

if ! need git; then
  err "git is required but not installed. Install git first."
  exit 1
fi
ok "git: $(git --version)"

if [[ ! -d "${SRC_DIR}" ]]; then
  err "Source skill directory not found: ${SRC_DIR}"
  err "Are you running this from the git-skill repository root?"
  exit 1
fi

if [[ ! -f "${SRC_DIR}/SKILL.md" ]]; then
  err "SKILL.md not found in ${SRC_DIR}. Corrupted source?"
  exit 1
fi

# ----- Existing install -----
if [[ -d "${SKILL_HOME}" ]]; then
  warn "An installation already exists at ${SKILL_HOME}"
  echo "Choose:" >&2
  echo "  [u] Upgrade in place (preserve any user customizations in scripts/)" >&2
  echo "  [r] Reinstall (back up current, install fresh)" >&2
  echo "  [c] Cancel" >&2
  read -r -p "Choice [u/r/c]: " choice
  case "${choice}" in
    u|U)
      log "Upgrading in place..."
      ;;
    r|R)
      backup="${SKILL_HOME}.bak.$(date +%s)"
      mv "${SKILL_HOME}" "${backup}"
      ok "Backed up existing install to ${backup}"
      ;;
    *)
      err "Cancelled by user"
      exit 0
      ;;
  esac
fi

# ----- Copy -----
mkdir -p "${SKILL_HOME}"

# Use cp -R to copy everything (preserves structure)
cp -R "${SRC_DIR}/." "${SKILL_HOME}/"
ok "Copied skill to ${SKILL_HOME}"

# ----- Fix exec bits -----
# Files from Windows ZIP / git clone may have lost +x
if [[ -d "${SKILL_HOME}/scripts" ]]; then
  while IFS= read -r -d '' f; do
    chmod +x "${f}"
  done < <(find "${SKILL_HOME}/scripts" -type f \( -name "*.sh" \) -print0)
  ok "Restored executable bits on shell scripts"
fi

# ----- Dependency check -----
if [[ -x "${SKILL_HOME}/scripts/install-deps.sh" ]]; then
  echo "" >&2
  log "Checking dependencies (gitleaks / gh / gitee-cli recommended)..."
  "${SKILL_HOME}/scripts/install-deps.sh" || warn "Dependency check skipped (non-fatal)"
fi

# ----- Done -----
echo "" >&2
ok "${C_BOLD}Installation complete!${C_RESET}"
echo "" >&2
echo "Next steps:" >&2
echo "  1. Restart Claude Code (or run /reload-skills if available)" >&2
echo "  2. Try:  /git help" >&2
echo "  3. Auth (one-time):" >&2
echo "       - Recommended: gh auth login (GitHub) / gitee auth login (Gitee)" >&2
echo "       - Or set GH_TOKEN / GITEE_TOKEN env vars" >&2
echo "       - Or configure ~/.ssh/id_* and add to your platform" >&2
echo "" >&2
echo "Uninstall: ${SCRIPT_DIR}/uninstall.sh" >&2
echo "" >&2