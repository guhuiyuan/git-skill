#!/usr/bin/env bash
#
# generate-readme.sh — Generate README from template.
#
# Levels: minimal | standard | detailed (default: standard)

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

TEMPLATES_README="${TEMPLATES_DIR}/readme"

LEVEL="standard"
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --level)  LEVEL="$2"; shift 2 ;;
    --minimal)  LEVEL="minimal"; shift ;;
    --standard) LEVEL="standard"; shift ;;
    --detailed) LEVEL="detailed"; shift ;;
    --force)   FORCE=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help|-h)
      cat <<EOF
Usage: generate-readme.sh [--level minimal|standard|detailed] [--force]

Levels:
  minimal    Title + 1-line description + License
  standard   Title + description + Install + Usage + License  (default)
  detailed   Full template with Features, Config, Testing, Deployment
EOF
      exit 0
      ;;
    *) log_err "Unknown: $1" ;;
  esac
done

TEMPLATE="${TEMPLATES_README}/README.${LEVEL}.md"
[[ ! -f "${TEMPLATE}" ]] && log_err "Template not found: ${TEMPLATE}"

# Detect project name (best effort)
PROJECT_NAME=""
if [[ -f "package.json" ]]; then
  PROJECT_NAME="$(grep -oE '"name"\s*:\s*"[^"]+"' package.json 2>/dev/null | head -n 1 | sed 's/.*"name"\s*:\s*"//; s/"$//' || echo "")"
fi
if [[ -z "${PROJECT_NAME}" ]] && [[ -f "pyproject.toml" ]]; then
  PROJECT_NAME="$(grep -oE '^name\s*=\s*"[^"]+"' pyproject.toml 2>/dev/null | head -n 1 | sed 's/^name\s*=\s*"//; s/"$//' || echo "")"
fi
if [[ -z "${PROJECT_NAME}" ]]; then
  PROJECT_NAME="$(basename "$(pwd)")"
fi

# Render template (substitute {{NAME}})
if [[ "${DRY_RUN}" == "true" ]]; then
  sed "s/{{NAME}}/${PROJECT_NAME}/g" "${TEMPLATE}"
  exit 0
fi

# Check existing README
README_PATH="README.md"
if [[ -f "${README_PATH}" ]] && [[ "${FORCE}" != "true" ]]; then
  log_warn "README.md exists. Use --force to overwrite."
  read -r -p "Overwrite? [y/N]: " confirm
  case "${confirm}" in
    y|Y|yes|YES) ;;
    *) log_err "Cancelled" ;;
  esac
fi

sed "s/{{NAME}}/${PROJECT_NAME}/g" "${TEMPLATE}" > "${README_PATH}"
log_ok "README.md created (${LEVEL} template)"

exit 0