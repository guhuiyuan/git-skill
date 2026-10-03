#!/usr/bin/env bash
#
# git-scan.sh — Manual secret scan (no commit).
#
# Forwards to check-secrets.sh with all arguments.

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
exec "${SCRIPT_DIR}/check-secrets.sh" "$@"