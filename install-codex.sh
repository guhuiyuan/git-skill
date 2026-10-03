#!/usr/bin/env bash
# install-codex.sh — Install git-skill into Codex CLI
#
# Usage:
#   ./install-codex.sh               # User-global (~/.codex/AGENTS.md)
#   ./install-codex.sh --project     # Project-local (./AGENTS.md)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SRC_SKILL="${SCRIPT_DIR}/skills/git"
CODEX_AGENTS="${SCRIPT_DIR}/compat/codex/AGENTS.md"

# Priority: env var > Claude install > fresh deploy
if [[ -n "${GIT_SKILL_HOME:-}" ]]; then
    :  # user override
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
install-codex.sh — Deploy git-skill to Codex CLI

USAGE:
    ./install-codex.sh               # User-global
    ./install-codex.sh --project     # Project-local
EOF
            exit 0
            ;;
    esac
done

if [[ "$MODE" == "user" ]]; then
    AGENTS_PATH="${HOME}/.codex/AGENTS.md"
    RULES_DIR="${HOME}/.codex"
else
    AGENTS_PATH="${SCRIPT_DIR}/AGENTS.md"
    RULES_DIR="${SCRIPT_DIR}"
fi

echo "[git-skill/codex] Mode: ${MODE}"
echo "[git-skill/codex] AGENTS.md target: ${AGENTS_PATH}"
echo "[git-skill/codex] Scripts target: ${GIT_SKILL_HOME}"

# 1. Deploy scripts
if [[ ! -d "$GIT_SKILL_HOME" ]]; then
    mkdir -p "$GIT_SKILL_HOME"
    cp -R "${SRC_SKILL}/." "$GIT_SKILL_HOME/"
    echo "[ok] Scripts deployed to ${GIT_SKILL_HOME}"
else
    echo "[skip] ${GIT_SKILL_HOME} already exists. Run uninstall.sh first."
fi

# 2. Install AGENTS.md
mkdir -p "$RULES_DIR"

if [[ -f "$AGENTS_PATH" ]] && [[ "$MODE" == "user" ]]; then
    # Append to existing AGENTS.md
    {
        echo ""
        echo "---"
        echo ""
        echo "# git-skill (appended $(date +%Y-%m-%d))"
        cat "$CODEX_AGENTS"
    } >> "$AGENTS_PATH"
    echo "[ok] Appended to existing ${AGENTS_PATH}"
else
    cp "$CODEX_AGENTS" "$AGENTS_PATH"
    echo "[ok] AGENTS.md installed at ${AGENTS_PATH}"
fi

echo ""
echo "Next steps:"
echo "  1. Restart Codex CLI"
echo "  2. Open any git project"
echo "  3. Ask: 'Help me set up this repo and push to GitHub'"
echo ""
echo "If scripts are elsewhere, set: export GIT_SKILL_HOME=/your/path"