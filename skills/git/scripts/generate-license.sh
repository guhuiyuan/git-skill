#!/usr/bin/env bash
#
# generate-license.sh — Generate LICENSE from chosen template.
#
# Available: MIT, Apache-2.0, GPL-3.0, BSD-3-Clause, Unlicense

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

TEMPLATES_LICENSE="${TEMPLATES_DIR}/license"

print_usage() {
  cat <<EOF
Usage: generate-license.sh --type <LICENSE> --name "<copyright holder>" [--year YYYY]

Available types:
  MIT
  Apache-2.0
  GPL-3.0
  BSD-3-Clause
  Unlicense
EOF
}

LICENSE_TYPE=""
COPYRIGHT_NAME=""
YEAR="$(date +%Y)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type) LICENSE_TYPE="$2"; shift 2 ;;
    --name) COPYRIGHT_NAME="$2"; shift 2 ;;
    --year) YEAR="$2"; shift 2 ;;
    --help|-h) print_usage; exit 0 ;;
    *) log_err "Unknown: $1" ;;
  esac
done

[[ -z "${LICENSE_TYPE}" ]] && log_err "--type required"
[[ -z "${COPYRIGHT_NAME}" ]] && log_err "--name required (copyright holder)"

TEMPLATE_FILE="${TEMPLATES_LICENSE}/${LICENSE_TYPE}.txt"
[[ ! -f "${TEMPLATE_FILE}" ]] && log_err "Template not found: ${TEMPLATE_FILE}"

# Substitute
if [[ "${DRY_RUN}" == "true" ]]; then
  sed -e "s/{{YEAR}}/${YEAR}/g" -e "s/{{NAME}}/${COPYRIGHT_NAME}/g" "${TEMPLATE_FILE}"
  exit 0
fi

LICENSE_PATH="LICENSE"
if [[ -f "${LICENSE_PATH}" ]]; then
  log_warn "LICENSE exists. Overwriting."
fi

sed -e "s/{{YEAR}}/${YEAR}/g" -e "s/{{NAME}}/${COPYRIGHT_NAME}/g" "${TEMPLATE_FILE}" > "${LICENSE_PATH}"
log_ok "LICENSE created (${LICENSE_TYPE}, ${YEAR}, ${COPYRIGHT_NAME})"