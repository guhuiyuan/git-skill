#!/usr/bin/env bash
#
# platform-detect.sh — Determine whether current repo is GitHub, Gitee, or other.
#
# Uses remote URL pattern matching. Outputs to stdout (one of: github | gitee | unknown).
#
# Usage:
#   ./platform-detect.sh              # auto-detect from cwd
#   ./platform-detect.sh --remote URL # detect from explicit URL

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

remote_url=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote) remote_url="$2"; shift 2 ;;
    --help|-h)
      cat <<EOF
Usage: platform-detect.sh [--remote URL]

Outputs one of: github | gitee | unknown
EOF
      exit 0
      ;;
    *) log_err "Unknown argument: $1" ;;
  esac
done

if [[ -z "${remote_url}" ]]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    remote_url="$(git remote get-url origin 2>/dev/null || echo "")"
  fi
fi

case "${remote_url}" in
  *github.com*|*githubusercontent*|*ghe.com*)
    echo "github"
    ;;
  *gitee.com*)
    echo "gitee"
    ;;
  "")
    echo "no-remote"
    ;;
  *)
    echo "unknown"
    ;;
esac