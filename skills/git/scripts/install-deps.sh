#!/usr/bin/env bash
#
# install-deps.sh — Check and recommend installation of git-skill dependencies.
#
# Required:
#   git (mandatory)
#
# Recommended (used by skill but optional, fallbacks exist):
#   gitleaks      — secret scanning (160+ rules; falls back to embedded 20)
#   gh            — GitHub CLI (preferred for GitHub operations)
#   gitee-cli     — oschina/gitee-cli (preferred for Gitee operations)
#
# Optional:
#   curl          — REST API fallback
#   ssh           — SSH remote operations
#   jq            — JSON parsing (skill uses portable alternatives)
#
# Usage:
#   ./install-deps.sh                  # Check only (report status)
#   ./install-deps.sh --install        # Try to install missing recommended tools

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

INSTALL_MODE=false
if [[ "${1:-}" == "--install" ]]; then
  INSTALL_MODE=true
fi

# ----- Detect package manager -----
detect_pkg_mgr() {
  if has_cmd brew;    then echo "brew"; return; fi
  if has_cmd apt-get; then echo "apt";  return; fi
  if has_cmd yum;     then echo "yum";  return; fi
  if has_cmd dnf;     then echo "dnf";  return; fi
  if has_cmd pacman;  then echo "pacman"; return; fi
  if has_cmd apk;     then echo "apk";   return; fi
  if has_cmd scoop;   then echo "scoop"; return; fi
  if has_cmd winget;  then echo "winget"; return; fi
  if has_cmd choco;   then echo "choco"; return; fi
  echo "none"
}

PKG_MGR=$(detect_pkg_mgr)

# ----- Check function -----
check_tool() {
  local name="$1"
  local required="$2"  # mandatory | recommended | optional
  local install_hint="$3"

  if has_cmd "${name}"; then
    local version
    case "${name}" in
      git)        version="$(git --version 2>/dev/null || echo unknown)" ;;
      gitleaks)   version="$(gitleaks version 2>/dev/null || echo installed)" ;;
      gh)         version="$(gh --version 2>/dev/null | head -n1 || echo installed)" ;;
      gitee)      version="$(gitee --version 2>/dev/null | head -n1 || echo installed)" ;;
      *)          version="installed" ;;
    esac
    log_ok "${name}: ${version}"
    return 0
  fi

  if [[ "${required}" == "mandatory" ]]; then
    log_err "${name} is required but not installed. ${install_hint}"
  else
    log_warn "${name}: not installed (${required}). ${install_hint}"
  fi
  return 1
}

# ----- Install function (best-effort) -----
install_tool() {
  local name="$1"
  if has_cmd "${name}"; then
    return 0
  fi

  log_info "Attempting to install ${name} via ${PKG_MGR}..."
  case "${name}:${PKG_MGR}" in
    gitleaks:brew)    brew install gitleaks 2>&1 | tail -n 3 >&2 ;;
    gitleaks:scoop)   scoop install gitleaks 2>&1 | tail -n 3 >&2 ;;
    gitleaks:winget)  winget install gitleaks 2>&1 | tail -n 3 >&2 ;;
    gitleaks:apt)     sudo apt-get install -y gitleaks 2>&1 | tail -n 3 >&2 ;;
    gh:brew)          brew install gh 2>&1 | tail -n 3 >&2 ;;
    gh:scoop)        scoop install gh 2>&1 | tail -n 3 >&2 ;;
    gh:winget)       winget install GitHub.cli 2>&1 | tail -n 3 >&2 ;;
    gh:apt)          sudo apt-get install -y gh 2>&1 | tail -n 3 >&2 ;;
    *) log_warn "Don't know how to install ${name} via ${PKG_MGR}. Please install manually." ;;
  esac
}

# ----- Main checks -----
log_info "Checking git-skill dependencies..."
echo ""

MISSING_RECOMMENDED=()

# Mandatory
if ! check_tool git mandatory "Install from https://git-scm.com/"; then
  exit 1
fi

# Recommended
if ! check_tool gitleaks recommended \
   "Install: brew install gitleaks / scoop install gitleaks / https://github.com/gitleaks/gitleaks/releases"; then
  MISSING_RECOMMENDED+=("gitleaks")
fi

if ! check_tool gh recommended \
   "Install: brew install gh / scoop install gh / https://cli.github.com/"; then
  MISSING_RECOMMENDED+=("gh")
fi

if ! check_tool gitee recommended \
   "Install from https://gitee.com/oschina/gitee-cli (no brew/scoop formula yet)"; then
  MISSING_RECOMMENDED+=("gitee")
fi

# Optional
check_tool curl optional "Install: any package manager" >/dev/null || true
check_tool ssh  optional "Install: any package manager" >/dev/null || true

echo ""

# ----- Auto-install mode -----
if [[ "${INSTALL_MODE}" == "true" ]] && [[ ${#MISSING_RECOMMENDED[@]} -gt 0 ]]; then
  log_info "Auto-install mode: attempting to install missing tools..."
  for tool in "${MISSING_RECOMMENDED[@]}"; do
    install_tool "${tool}"
  done
fi

# ----- Summary -----
if [[ ${#MISSING_RECOMMENDED[@]} -eq 0 ]]; then
  log_ok "All recommended tools are installed. You're all set!"
else
  log_warn "Missing recommended tools: ${MISSING_RECOMMENDED[*]}"
  log_info "The skill will work with reduced functionality. See above for install hints."
fi

echo ""
log_info "Auth setup: run '/git auth' for guided configuration (OS keychain recommended)."
exit 0