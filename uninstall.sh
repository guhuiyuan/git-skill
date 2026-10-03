#!/usr/bin/env bash
#
# uninstall.sh — Remove git-skill from ~/.claude/skills/git/

set -euo pipefail
IFS=$'\n\t'

SKILL_NAME="git"
SKILL_HOME="${SKILL_HOME:-${HOME}/.claude/skills/${SKILL_NAME}}"

if [[ ! -d "${SKILL_HOME}" ]]; then
  echo "[git-skill] No installation found at ${SKILL_HOME}"
  exit 0
fi

echo "[git-skill] Will remove: ${SKILL_HOME}"
read -r -p "Are you sure? [y/N]: " confirm
case "${confirm}" in
  y|Y|yes|YES)
    rm -rf "${SKILL_HOME}"
    echo "[ok] Removed ${SKILL_HOME}"
    echo ""
    echo "Restart Claude Code to pick up changes."
    ;;
  *)
    echo "[git-skill] Cancelled"
    exit 0
    ;;
esac