#!/usr/bin/env bash
#
# proactive-advisor.sh — Detect context and suggest project management actions.
#
# Designed to be called by Claude Code at natural breakpoints in a conversation.
# Returns a list of suggestions that Claude can surface to the user.
#
# Usage:
#   ./proactive-advisor.sh              # Analyze current cwd + recent activity
#   ./proactive-advisor.sh --json       # Machine-readable suggestions
#   ./proactive-advisor.sh --quiet      # Only output if there are suggestions
#
# Suggestions include:
#   - Uncommitted changes accumulated → /git commit
#   - Many files changed without branch → /git branch new <name>
#   - New project type detected → /git gitignore / readme / license
#   - Long-lived branch → /git rebase / merge main
#   - About to refactor/fix/release → suggest workflow patterns
#   - Stale branches → /git branch delete
#   - Many commits ahead of remote → /git push / /git pr
#   - Sensitive files present (not in .gitignore) → /git scan

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

QUIET=false
JSON_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet)  QUIET=true; shift ;;
    --json)   JSON_MODE=true; OUTPUT_FORMAT=json; shift ;;
    --help|-h)
      cat <<EOF
Usage: proactive-advisor.sh [options]

Analyzes current working directory and recent context to suggest
project management actions at natural breakpoints.

Options:
  --json    Machine-readable JSON output
  --quiet   Only output if there are suggestions
  --help    Show this help

Output: a list of suggestions like:
  [HIGH] /git commit -m "feat: ..."  -- 12 uncommitted files accumulated
  [LOW]  /git gitignore              -- detected Node.js project without .gitignore
EOF
      exit 0
      ;;
    *) log_err "Unknown argument: $1" ;;
  esac
done

# ----- Collect state -----
SUGGESTIONS=()

is_repo=false
uncommitted_count=0
untracked_count=0
branch=""
remote_branch_diff=""
is_default_branch=true
has_remote=false
remote_url=""
project_type=""
has_gitignore=false
has_readme=false
has_license=false
sensitive_files_present=()
local_commits_ahead=0
total_branches=0
merged_branches=()

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  is_repo=true

  branch="$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "")"

  # Count uncommitted changes
  if ! git diff --quiet 2>/dev/null; then
    uncommitted_count="$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')"
  fi
  untracked_count="$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')"

  # Remote info
  if git remote get-url origin >/dev/null 2>&1; then
    has_remote=true
    remote_url="$(git remote get-url origin)"
  fi

  # Default branch detection
  local default_branch
  default_branch="$(git remote show origin 2>/dev/null | sed -n 's/^.*HEAD branch: //p' || echo "")"
  if [[ -n "${default_branch}" && "${branch}" != "${default_branch}" ]]; then
    is_default_branch=false
  fi

  # Commits ahead of remote
  if [[ "${has_remote}" == "true" ]]; then
    local ahead
    ahead="$(git rev-list --count "origin/${default_branch:-main}..HEAD" 2>/dev/null || echo 0)"
    local_commits_ahead="${ahead:-0}"
  fi

  # Total / merged branches
  total_branches="$(git branch --format='%(refname:short)' 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "${total_branches}" -gt 1 ]]; then
    while IFS= read -r b; do
      [[ -z "$b" ]] && continue
      [[ "$b" == "${branch}" ]] && continue
      if git merge-base --is-ancestor "$b" "${default_branch:-main}" 2>/dev/null; then
        merged_branches+=("$b")
      fi
    done < <(git branch --format='%(refname:short)' 2>/dev/null)
  fi

  # Project type detection
  if [[ -f "package.json" ]];                   then project_type="node"; fi
  if [[ -f "pyproject.toml" || -f "setup.py" || -f "requirements.txt" ]]; then project_type="python"; fi
  if [[ -f "pom.xml" || -f "build.gradle" ]];   then project_type="java"; fi
  if [[ -f "go.mod" ]];                         then project_type="go"; fi
  if [[ -f "Cargo.toml" ]];                     then project_type="rust"; fi
  if compgen -G "*.csproj" >/dev/null || compgen -G "*.sln" >/dev/null; then project_type="dotnet"; fi

  # File presence
  [[ -f ".gitignore" ]] && has_gitignore=true
  [[ -f "README.md" || -f "readme.md" || -f "README.rst" || -f "README" ]] && has_readme=true
  [[ -f "LICENSE" || -f "LICENSE.md" || -f "LICENSE.txt" ]] && has_license=true

  # Sensitive files in working tree (not yet .gitignored)
  for pattern in ".env" ".env.local" "credentials.json" "*.pem" "*.key"; do
    if compgen -G "$pattern" >/dev/null; then
      sensitive_files_present+=("$pattern")
    fi
  done
fi

# ----- Suggestion rules -----
add_suggestion() {
  # add_suggestion <priority: HIGH|MEDIUM|LOW> <command> <reason>
  local priority="$1" cmd="$2" reason="$3"
  SUGGESTIONS+=("{\"priority\":\"${priority}\",\"command\":\"${cmd}\",\"reason\":\"${reason}\"}")
}

# Rule 1: Many uncommitted changes → commit
if [[ "${is_repo}" == "true" ]]; then
  total_changes=$((uncommitted_count + untracked_count))
  if [[ ${total_changes} -ge 10 ]]; then
    add_suggestion "HIGH" "/git commit -m \"...\"" "${total_changes} uncommitted files accumulated"
  elif [[ ${total_changes} -ge 5 ]]; then
    add_suggestion "MEDIUM" "/git commit -m \"...\"" "${total_changes} files modified"
  fi
fi

# Rule 2: Not on default branch with new work → branch suggestion
if [[ "${is_repo}" == "true" ]] && [[ "${is_default_branch}" == "false" ]]; then
  if [[ ${uncommitted_count} -gt 0 ]] || [[ ${untracked_count} -gt 0 ]]; then
    add_suggestion "LOW" "/git status" "On non-default branch ${branch} with uncommitted work"
  fi
fi

# Rule 3: Project type detected but no .gitignore
if [[ -n "${project_type}" ]] && [[ "${has_gitignore}" == "false" ]]; then
  add_suggestion "HIGH" "/git gitignore" "Detected ${project_type} project without .gitignore"
fi

# Rule 4: No README on project with substantial content
if [[ "${is_repo}" == "true" ]] && [[ "${has_readme}" == "false" ]]; then
  local src_files
  src_files="$(find . -maxdepth 3 -type f \( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.go' -o -name '*.rs' -o -name '*.java' \) -not -path './.git/*' 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "${src_files}" -ge 3 ]]; then
    add_suggestion "MEDIUM" "/git readme" "Project has ${src_files} source files but no README"
  fi
fi

# Rule 5: No LICENSE
if [[ "${is_repo}" == "true" ]] && [[ "${has_license}" == "false" ]]; then
  add_suggestion "MEDIUM" "/git license" "No LICENSE file detected"
fi

# Rule 6: Commits ahead of remote
if [[ "${local_commits_ahead}" -ge 5 ]]; then
  add_suggestion "HIGH" "/git push && /git pr new" "${local_commits_ahead} commits ahead of remote"
elif [[ "${local_commits_ahead}" -ge 1 ]]; then
  add_suggestion "MEDIUM" "/git push" "${local_commits_ahead} commit(s) not pushed"
fi

# Rule 7: No remote + has commits
if [[ "${is_repo}" == "true" ]] && [[ "${has_remote}" == "false" ]]; then
  local commit_count
  commit_count="$(git rev-list --count HEAD 2>/dev/null || echo 0)"
  if [[ "${commit_count}" -ge 1 ]]; then
    add_suggestion "HIGH" "/git create-repo --platform <github|gitee>" "Local repo has ${commit_count} commit(s) but no remote configured"
  fi
fi

# Rule 8: Sensitive files in working tree
if [[ ${#sensitive_files_present[@]} -gt 0 ]]; then
  add_suggestion "HIGH" "/git scan && add ${sensitive_files_present[0]} to .gitignore" "Sensitive file(s) in working tree: ${sensitive_files_present[*]}"
fi

# Rule 9: Merged branches that can be cleaned
if [[ ${#merged_branches[@]} -gt 0 ]]; then
  local count=${#merged_branches[@]}
  add_suggestion "LOW" "/git branch delete <name>" "${count} merged branch(es) can be cleaned: ${merged_branches[*]:0:3}"
fi

# Rule 10: Long-lived feature branch
if [[ "${is_repo}" == "true" ]] && [[ "${is_default_branch}" == "false" ]] && [[ "${has_remote}" == "true" ]]; then
  local branch_age_days
  branch_age_days=$(( ( $(date +%s) - $(git log -1 --format=%ct "${branch}" 2>/dev/null || echo 0) ) / 86400 ))
  if [[ "${branch_age_days}" -ge 14 ]]; then
    add_suggestion "MEDIUM" "/git rebase <default-branch>" "Branch ${branch} is ${branch_age_days} days old; consider rebasing"
  fi
fi

# ----- Output -----
if [[ "${QUIET}" == "true" ]] && [[ ${#SUGGESTIONS[@]} -eq 0 ]]; then
  exit 0
fi

if [[ "${JSON_MODE}" == "true" ]]; then
  if [[ ${#SUGGESTIONS[@]} -eq 0 ]]; then
    echo '{"suggestions":[]}'
  else
    local joined
    joined="$(IFS=,; echo "${SUGGESTIONS[*]}")"
    echo "{\"suggestions\":[${joined}]}"
  fi
else
  if [[ ${#SUGGESTIONS[@]} -eq 0 ]]; then
    if [[ "${QUIET}" != "true" ]]; then
      log_ok "No proactive suggestions right now. Continue your work!"
    fi
    exit 0
  fi

  printf '\n%s%s%s Proactive suggestions:\n' "${_C_BOLD}${_C_CYAN}" "" "${_C_RESET}"
  for s in "${SUGGESTIONS[@]}"; do
    local priority cmd reason
    priority="$(echo "$s" | sed -n 's/.*"priority":"\([^"]*\)".*/\1/p')"
    cmd="$(echo "$s" | sed -n 's/.*"command":"\([^"]*\)".*/\1/p')"
    reason="$(echo "$s" | sed -n 's/.*"reason":"\([^"]*\)".*/\1/p')"
    case "$priority" in
      HIGH)   printf '  %s[HIGH]%s   %s\n     → %s\n' "${_C_RED}"   "${_C_RESET}" "$cmd" "$reason" ;;
      MEDIUM) printf '  %s[MED]%s    %s\n     → %s\n' "${_C_YELLOW}" "${_C_RESET}" "$cmd" "$reason" ;;
      LOW)    printf '  %s[LOW]%s    %s\n     → %s\n' "${_C_CYAN}"   "${_C_RESET}" "$cmd" "$reason" ;;
    esac
  done
  printf '\n'
fi

exit 0