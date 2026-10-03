#!/usr/bin/env bash
#
# create-repo.sh — Create a remote repository on GitHub or Gitee.
#
# Usage:
#   create-repo.sh --platform github|gitee --name <name> [--public|--private]
#                   [--description "..."] [--org <org>] [--remote-name origin]

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

PLATFORM=""
NAME=""
VISIBILITY="public"
DESCRIPTION=""
ORG=""
REMOTE_NAME="origin"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)    PLATFORM="$2"; shift 2 ;;
    --name)        NAME="$2"; shift 2 ;;
    --public)      VISIBILITY="public"; shift ;;
    --private)     VISIBILITY="private"; shift ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --org)         ORG="$2"; shift 2 ;;
    --remote-name) REMOTE_NAME="$2"; shift 2 ;;
    --help|-h)
      cat <<EOF
Usage: create-repo.sh --platform github|gitee --name <name> [options]

Required:
  --platform NAME         github or gitee
  --name NAME             repository name

Options:
  --public | --private    visibility (default: public)
  --description "..."     repo description
  --org ORG               organization (GitHub only)
  --remote-name NAME      local remote name (default: origin)
  --dry-run               show what would be done

After creation, the script will offer to add the remote and push.
EOF
      exit 0
      ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) log_err "Unknown argument: $1" ;;
  esac
done

[[ -z "${PLATFORM}" ]] && log_err "--platform required"
[[ -z "${NAME}" ]]    && log_err "--name required"

case "${PLATFORM}" in
  github)
    # shellcheck source=_platform/github.sh
    source "${SCRIPT_DIR}/_platform/github.sh"
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[dry-run] Would create GitHub repo: ${ORG:+${ORG}/}${NAME} (${VISIBILITY})"
      exit 0
    fi
    gh_create_repo "${NAME}" "${VISIBILITY}" "${DESCRIPTION}" "${ORG}"
    ;;
  gitee)
    # shellcheck source=_platform/gitee.sh
    source "${SCRIPT_DIR}/_platform/gitee.sh"
    if [[ "${DRY_RUN}" == "true" ]]; then
      log_info "[dry-run] Would create Gitee repo: ${NAME} (${VISIBILITY})"
      exit 0
    fi
    gitee_create_repo "${NAME}" "${VISIBILITY}" "${DESCRIPTION}"
    ;;
  *)
    log_err "Unsupported platform: ${PLATFORM}"
    ;;
esac

# ----- Add remote -----
case "${PLATFORM}" in
  github)
    if [[ -n "${ORG}" ]]; then
      remote_url="git@github.com:${ORG}/${NAME}.git"
      [[ -n "${GH_TOKEN:-}" ]] && remote_url="https://github.com/${ORG}/${NAME}.git"
    else
      # Try to detect user from gh
      if has_cmd gh && gh auth status >/dev/null 2>&1; then
        user="$(gh api user --jq .login 2>/dev/null || echo "")"
        if [[ -n "${user}" ]]; then
          remote_url="git@github.com:${user}/${NAME}.git"
        else
          remote_url="https://github.com/${user:-<owner>}/${NAME}.git"
        fi
      else
        remote_url="https://github.com/<your-username>/${NAME}.git"
      fi
    fi
    ;;
  gitee)
    user=""
    if has_cmd gitee && gitee auth status >/dev/null 2>&1; then
      user="$(gitee user info --format '{{.login}}' 2>/dev/null || echo "")"
    fi
    remote_url="https://gitee.com/${user:-<your-username>}/${NAME}.git"
    ;;
esac

log_info "Suggested remote URL: ${remote_url}"
read -r -p "Add as remote '${REMOTE_NAME}' and push? [Y/n]: " confirm
case "${confirm}" in
  ""|y|Y|yes|YES)
    if git remote get-url "${REMOTE_NAME}" 2>/dev/null; then
      log_warn "Remote '${REMOTE_NAME}' already exists. Updating URL."
      git remote set-url "${REMOTE_NAME}" "${remote_url}"
    else
      git remote add "${REMOTE_NAME}" "${remote_url}"
    fi
    log_ok "Remote added: ${REMOTE_NAME} -> ${remote_url}"

    branch="$(git symbolic-ref --short HEAD 2>/dev/null || echo main)"
    log_info "Pushing to ${REMOTE_NAME}/${branch}..."
    "${SCRIPT_DIR}/git-push-flow.sh" --set-upstream "${REMOTE_NAME}" "${branch}"
    ;;
  *)
    log_info "Skipping remote setup. Add manually with:"
    log_info "  git remote add ${REMOTE_NAME} ${remote_url}"
    ;;
esac