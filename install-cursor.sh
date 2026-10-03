#!/usr/bin/env bash
# install-cursor.sh — Install git-skill into Cursor rules
#
# Usage:
#   ./install-cursor.sh              # User-global (~/.cursor/rules/)
#   ./install-cursor.sh --project    # Project-local (.cursor/rules/)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SRC_SKILL="${SCRIPT_DIR}/skills/git"
CURSOR_MDC="${SCRIPT_DIR}/compat/cursor/git.mdc"

# Where to deploy scripts (shared with Claude install if you ran install.sh)
# Priority order: env var > Claude install location > fresh deploy to ~/.local/share
if [[ -n "${GIT_SKILL_HOME:-}" ]]; then
    :  # user explicit override wins
elif [[ -d "${HOME}/.claude/skills/git" ]]; then
    GIT_SKILL_HOME="${HOME}/.claude/skills/git"
    echo "[note] Reusing Claude install at ${GIT_SKILL_HOME}"
else
    GIT_SKILL_HOME="${HOME}/.local/share/git-skill"
fi

MODE="user"
for arg in "$@"; do
    case "$arg" in
        --project) MODE="project" ;;
        --user)    MODE="user" ;;
        --help|-h)
            cat <<EOF
install-cursor.sh — Deploy git-skill to Cursor

USAGE:
    ./install-cursor.sh              # User-global
    ./install-cursor.sh --project    # Project-local
EOF
            exit 0
            ;;
    esac
done

if [[ "$MODE" == "user" ]]; then
    RULES_DIR="${HOME}/.cursor/rules"
else
    RULES_DIR="${SCRIPT_DIR}/.cursor/rules"
fi

echo "[git-skill/cursor] Mode: ${MODE}"
echo "[git-skill/cursor] Rules dir: ${RULES_DIR}"
echo "[git-skill/cursor] Scripts target: ${GIT_SKILL_HOME}"

# 1. Deploy scripts to shared location
if [[ ! -d "$GIT_SKILL_HOME" ]]; then
    mkdir -p "$GIT_SKILL_HOME"
    cp -R "${SRC_SKILL}/." "$GIT_SKILL_HOME/"
    echo "[ok] Scripts deployed to ${GIT_SKILL_HOME}"
else
    echo "[skip] ${GIT_SKILL_HOME} already exists. Run uninstall.sh first to reinstall."
fi

# 2. Install rule file
mkdir -p "$RULES_DIR"
cp "$CURSOR_MDC" "$RULES_DIR/git.mdc"
echo "[ok] Rule file installed at ${RULES_DIR}/git.mdc"

echo ""
echo "Next steps:"
echo "  1. Restart Cursor (or reload rules)"
echo "  2. Open any git project"
echo "  3. Ask: 'Help me commit and push these changes'"
echo ""
echo "If git-skill scripts are elsewhere, set: export GIT_SKILL_HOME=/your/path"