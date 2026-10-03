#!/usr/bin/env bash
#
# hook-precommit.sh — PreToolUse hook for ~/.claude/settings.json
#
# Intercepts Bash commands matching `git commit` or `git push`,
# automatically runs check-secrets.sh on staged changes.
#
# Setup: add to ~/.claude/settings.json:
#   {
#     "hooks": {
#       "PreToolUse": [{
#         "matcher": "Bash",
#         "hooks": [{
#           "type": "command",
#           "command": "${HOME}/.claude/skills/git/scripts/hook-precommit.sh"
#         }]
#       }]
#     }
#   }
#
# Input: Claude Code passes tool input as JSON to stdin:
#   {"tool_name":"Bash","tool_input":{"command":"git commit -m 'foo'","description":"..."}}
#
# Output: exit 0 = allow, exit 2 = block (stderr printed to user)
#         We exit 2 with a clear message when secrets are detected.

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CHECK_SECRETS="${SCRIPT_DIR}/check-secrets.sh"

# Read JSON from stdin
input="$(cat)"
command="$(printf '%s' "${input}" | grep -oE '"command"\s*:\s*"[^"]*"' | sed 's/^"command"\s*:\s*"//; s/"$//' || echo "")"

# Only act on git commit / git push commands
case "${command}" in
  git\ commit*|git\ push*)
    ;;
  *)
    exit 0  # allow everything else
    ;;
esac

# Don't block if not in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

# Run secret scan (staged)
if [[ -x "${CHECK_SECRETS}" ]]; then
  if ! "${CHECK_SECRETS}" --staged --severity critical >/dev/null 2>&1; then
    echo "[git-skill hook] Secret scan detected CRITICAL findings. Run /git scan to see details." >&2
    echo "[git-skill hook] Blocked: $(echo "${command}" | head -c 80)" >&2
    exit 2
  fi

  # Also warn on HIGH (but don't block)
  if ! "${CHECK_SECRETS}" --staged --severity high >/dev/null 2>&1; then
    echo "[git-skill hook] HIGH secret findings detected. Consider /git scan --force-allow-high to proceed." >&2
  fi
fi

exit 0