#!/usr/bin/env bash
#
# git-clone-flow.sh — Clone a repository with platform-aware auth.

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

print_usage() {
  cat <<EOF
Usage: git-clone-flow.sh <url> [target-dir]

Clone a repository using the best available auth method.
EOF
}

URL="${1:-}"
TARGET="${2:-}"

if [[ -z "${URL}" ]]; then
  print_usage
  exit 1
fi

# Detect platform
case "${URL}" in
  *github.com*|*githubusercontent*|*ghe.com*)
    PLATFORM="github"
    ;;
  *gitee.com*)
    PLATFORM="gitee"
    ;;
  *)
    PLATFORM="unknown"
    ;;
esac

log_info "Cloning ${URL} (platform: ${PLATFORM})..."

# Convert HTTPS to SSH if SSH is available and no token
if [[ "${URL}" == https://* ]] && [[ "${PLATFORM}" != "unknown" ]]; then
  case "${PLATFORM}" in
    github)
      if [[ -z "${GH_TOKEN:-}" ]] && [[ ! -f "${HOME}/.ssh/id_ed25519" ]] && [[ ! -f "${HOME}/.ssh/id_rsa" ]]; then
        # No SSH, no token → warn but try
        log_warn "No GitHub auth configured. Run /git auth for setup."
      fi
      ;;
    gitee)
      if [[ -z "${GITEE_TOKEN:-}" ]] && [[ ! -f "${HOME}/.ssh/id_ed25519" ]] && [[ ! -f "${HOME}/.ssh/id_rsa" ]]; then
        log_warn "No Gitee auth configured. Run /git auth for setup."
      fi
      ;;
  esac
fi

# Run clone
if [[ -n "${TARGET}" ]]; then
  run_cmd git clone "${URL}" "${TARGET}"
else
  run_cmd git clone "${URL}"
fi

log_ok "Clone successful."

# Offer next steps
target_dir="${TARGET:-$(basename "${URL}" .git)}"
log_info "
Next:
  cd ${target_dir}
  /git status
"