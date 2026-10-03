#!/usr/bin/env bash
#
# common.sh — Shared library for git-skill bash scripts.
#
# Source this file from any script:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/_lib/common.sh"
#
# Provides: logging, color, error handling, JSON output, dry-run, help parsing.

set -euo pipefail
IFS=$'\n\t'

# ----- Constants -----
GIT_SKILL_VERSION="1.0.0"

# ----- Detect script / skill directories -----
# When sourced from /scripts/_lib/common.sh, parent of parent is skills/git/
_LIB_COMMON_FILE="${BASH_SOURCE[0]:-${0}}"
_LIB_DIR="$(cd "$(dirname "${_LIB_COMMON_FILE}")" && pwd)"
SCRIPTS_DIR="$(cd "${_LIB_DIR}/.." && pwd)"
SKILL_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
TEMPLATES_DIR="${SKILL_DIR}/templates"
REFERENCES_DIR="${SKILL_DIR}/references"
export SCRIPTS_DIR SKILL_DIR TEMPLATES_DIR REFERENCES_DIR

# ----- Color setup -----
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  _C_RED=$'\033[31m'
  _C_GREEN=$'\033[32m'
  _C_YELLOW=$'\033[33m'
  _C_CYAN=$'\033[36m'
  _C_BOLD=$'\033[1m'
  _C_DIM=$'\033[2m'
  _C_RESET=$'\033[0m'
else
  _C_RED=''; _C_GREEN=''; _C_YELLOW=''; _C_CYAN=''; _C_BOLD=''; _C_DIM=''; _C_RESET=''
fi
export _C_RED _C_GREEN _C_YELLOW _C_CYAN _C_BOLD _C_DIM _C_RESET

# ----- Logging functions (stderr) -----
_log() {
  # _log <level> <message>
  local level="$1"; shift
  local color
  case "${level}" in
    info)  color="${_C_CYAN}" ;;
    ok)    color="${_C_GREEN}" ;;
    warn)  color="${_C_YELLOW}" ;;
    err)   color="${_C_RED}" ;;
    debug) color="${_C_DIM}" ;;
    *)     color="" ;;
  esac
  printf '%s[%s]%s %s\n' "${color}" "${level}" "${_C_RESET}" "$*" >&2
}

log_info()  { _log info "$@"; }
log_ok()    { _log ok "$@"; }
log_warn()  { _log warn "$@"; }
log_err()   { _log err "$@" >&2; exit 1; }
log_debug() { [[ -n "${DEBUG:-}" ]] && _log debug "$@" || true; }

# ----- Print to user (stdout) -----
print() { printf '%s\n' "$*"; }

# ----- JSON output helpers -----
is_json_mode() { [[ "${OUTPUT_FORMAT:-}" == "json" ]]; }

emit_json() {
  # emit_json <json-string>
  if is_json_mode; then
    print "$1"
  fi
}

# ----- Argument parsing -----
DRY_RUN="false"
VERBOSE="false"
OUTPUT_FORMAT="human"

parse_common_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)   DRY_RUN="true"; shift ;;
      --verbose|-v) VERBOSE="true"; DEBUG=1; shift ;;
      --json)      OUTPUT_FORMAT="json"; shift ;;
      --no-color)  NO_COLOR=1; shift ;;
      --help|-h)   if declare -f print_usage >/dev/null; then print_usage; exit 0; fi; shift ;;
      --) shift; break ;;
      -*) log_err "Unknown flag: $1 (use --help)";;
      *)  break ;;
    esac
  done
}

run_cmd() {
  # run_cmd <command...> — respects DRY_RUN
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[dry-run] $*"
    return 0
  fi
  log_debug "Running: $*"
  "$@"
}

# ----- Pre-flight: are we in a git repo? -----
require_git_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_err "Not a git repository. Run /git init first, or /git clone <url>."
  fi
}

# ----- Resolve working directory -----
# Skill always uses current cwd; never cd elsewhere.
assert_cwd_is_workdir() {
  local cwd
  cwd="$(pwd)"
  if [[ "${cwd}" != "$(pwd -P 2>/dev/null || pwd)" ]]; then
    log_warn "Working directory has symlinks; resolved to $(pwd -P 2>/dev/null || pwd)"
  fi
}

# ----- Severity levels -----
SEVERITY_CRITICAL=3
SEVERITY_HIGH=2
SEVERITY_LOW=1

# ----- Print banner -----
print_banner() {
  printf '%s%s%s\n' "${_C_BOLD}${_C_CYAN}" "$*" "${_C_RESET}" >&2
}

# ----- Exit codes -----
EXIT_OK=0
EXIT_GENERAL=1
EXIT_BLOCKED=2   # CRITICAL finding
EXIT_WARNED=3    # HIGH finding (force-allowed)

# ----- Check command exists -----
has_cmd() { command -v "$1" >/dev/null 2>&1; }

# ----- Platform detection -----
detect_os() {
  case "$(uname -s 2>/dev/null || echo Windows)" in
    Linux*)   echo "linux" ;;
    Darwin*)  echo "macos" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows-gitbash" ;;
    *) echo "unknown" ;;
  esac
}