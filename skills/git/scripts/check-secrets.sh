#!/usr/bin/env bash
#
# check-secrets.sh — Scan for secrets before commit/push.
#
# Layered architecture:
#   Layer 1: gitleaks binary (preferred) - 160+ rules
#   Layer 2: Embedded rules (fallback) - 20 high-hit patterns
#   Layer 3: Filename rules - always applied
#
# Usage:
#   check-secrets.sh                              # scan staged (default)
#   check-secrets.sh --all                        # scan all history
#   check-secrets.sh --working-tree               # scan unstaged changes
#   check-secrets.sh --staged                     # scan staged (default)
#   check-secrets.sh --severity critical|high|low # filter
#   check-secrets.sh --force-allow-high           # bypass HIGH findings
#   check-secrets.sh --json                       # JSON output
#
# Exit codes:
#   0 = clean
#   1 = CRITICAL findings (cannot bypass)
#   2 = HIGH findings (force-allow to skip)
#   3 = LOW only (always allowed)

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=_lib/common.sh
source "${SCRIPT_DIR}/_lib/common.sh"

# ----- Defaults -----
SCAN_TARGET="staged"
SEVERITY_FILTER="all"
FORCE_ALLOW_HIGH=false
USE_GITLEAKS_AUTO=true   # auto-detect: use gitleaks if available

# ----- Args -----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)          SCAN_TARGET="all"; shift ;;
    --working-tree) SCAN_TARGET="working-tree"; shift ;;
    --staged)       SCAN_TARGET="staged"; shift ;;
    --severity)     SEVERITY_FILTER="$2"; shift 2 ;;
    --force-allow-high) FORCE_ALLOW_HIGH=true; shift ;;
    --no-gitleaks)  USE_GITLEAKS_AUTO=false; shift ;;
    --json)         OUTPUT_FORMAT="json"; shift ;;
    --dry-run)      DRY_RUN=true; shift ;;
    --verbose|-v)   DEBUG=1; shift ;;
    --help|-h)
      cat <<EOF
Usage: check-secrets.sh [options]

Scan staged / working-tree / all git history for secrets.

Options:
  --all                  Scan entire history (default: staged)
  --working-tree         Scan unstaged changes
  --staged               Scan staged (default)
  --severity LEVEL       Filter: critical|high|low|all (default: all)
  --force-allow-high     Bypass HIGH findings (CRITICAL still blocks)
  --no-gitleaks          Skip gitleaks, use embedded rules only
  --json                 JSON output for machine parsing
  --dry-run              Print what would be done
  --verbose              Verbose output
  --help, -h             Show this help

Exit codes:
  0 = clean
  1 = CRITICAL findings (cannot bypass)
  2 = HIGH findings (force-allow to skip)
  3 = LOW only (allowed)
EOF
      exit 0
      ;;
    *) log_err "Unknown argument: $1 (use --help)" ;;
  esac
done

# ----- Embedded filename rules -----
# Format: <severity>|<glob>
EMBEDDED_FILE_RULES=(
  "critical|.env"
  "critical|.env.*"
  "critical|*.pem"
  "critical|*.key"
  "critical|*.p12"
  "critical|*.pfx"
  "critical|id_rsa"
  "critical|id_rsa.*"
  "critical|id_ed25519"
  "critical|id_ed25519.*"
  "critical|id_dsa"
  "critical|id_ecdsa"
  "critical|*.keystore"
  "critical|credentials.json"
  "critical|service-account.json"
  "critical|.npmrc"
  "critical|.pypirc"
  "critical|.netrc"
  "critical|pgpass"
  "critical|gha-creds-*"
  "high|*.secret"
  "high|*secret*"
  "high|*password*"
  "high|*credential*"
  "high|*.sqlite"
  "high|*.db"
  "high|*.bak"
  "high|*.swp"
  "high|.DS_Store"
  "low|*.log"
  "low|*.tmp"
  "low|node_modules"
  "low|venv"
  "low|__pycache__"
  "low|target"
  "low|build"
  "low|dist"
)

# ----- Embedded content rules -----
# Format: <severity>|<rule-name>|<regex>
EMBEDDED_CONTENT_RULES=(
  "critical|aws-access-key|AKIA[0-9A-Z]{16}"
  "critical|aws-secret-key|aws_secret_access_key[=:][\"']?[A-Za-z0-9/+=]{40}[\"']?"
  "critical|github-pat|ghp_[A-Za-z0-9]{36}"
  "critical|github-fine-grained|github_pat_[A-Za-z0-9_]{82}"
  "critical|github-oauth|gho_[A-Za-z0-9]{36}"
  "critical|github-user|ghu_[A-Za-z0-9]{36}"
  "critical|github-server|ghs_[A-Za-z0-9]{36}"
  "critical|github-refresh|ghr_[A-Za-z0-9]{36}"
  "critical|openai-api-key|sk-[A-Za-z0-9]{20,}"
  "critical|openai-project|sk-proj-[A-Za-z0-9_-]{40,}"
  "critical|anthropic-api-key|sk-ant-[A-Za-z0-9_-]{40,}"
  "critical|private-key|-----BEGIN (RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY-----"
  "critical|stripe-live-secret|sk_live_[0-9a-zA-Z]{24,}"
  "critical|stripe-live-restricted|rk_live_[0-9a-zA-Z]{24,}"
  "critical|google-api-key|AIza[0-9A-Za-z_-]{35}"
  "critical|jwt-token|eyJ[A-Za-z0-9_-]+\\.eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+"
  "critical|slack-token|xox[baprs]-[0-9]{10,}-[0-9]{10,}-[A-Za-z0-9]{24,}"
  "high|generic-password|(password|passwd|pwd)[=:][\"'][^\"']{8,}[\"']"
  "high|generic-api-key|(api[_-]?key|token|secret)[=:][\"'][A-Za-z0-9_\\-]{16,}[\"']"
)

# ----- Severity filtering -----
severity_matches() {
  local sev="$1" filter="$2"
  case "$filter" in
    all) return 0 ;;
    critical) [[ "$sev" == "critical" ]] ;;
    high) [[ "$sev" == "high" ]] ;;
    low) [[ "$sev" == "low" ]] ;;
    *) return 1 ;;
  esac
}

# ----- Glob matching -----
# Portable glob match (avoid bash extglob edge cases)
matches_glob() {
  local file="$1" pattern="$2"
  # shellcheck disable=SC2053  # intentional glob comparison
  [[ "$file" == $pattern ]]
}

# ----- Gather files to scan -----
get_files() {
  case "$SCAN_TARGET" in
    staged)
      git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true
      ;;
    working-tree)
      git diff --name-only --diff-filter=ACMR 2>/dev/null || true
      ;;
    all)
      git ls-files 2>/dev/null || true
      ;;
  esac
}

# ----- Get diff content for a file -----
get_diff_content() {
  local file="$1"
  case "$SCAN_TARGET" in
    staged)
      git diff --cached -- "$file" 2>/dev/null | head -n 200 || true
      ;;
    working-tree)
      git diff -- "$file" 2>/dev/null | head -n 200 || true
      ;;
    all)
      git show "HEAD:${file}" 2>/dev/null | head -n 200 || true
      ;;
  esac
}

# ----- Scan with gitleaks -----
scan_with_gitleaks() {
  if ! has_cmd gitleaks; then
    return 1   # not available
  fi

  log_info "Using gitleaks (preferred)..."

  # NOTE: do NOT pass --redact. gitleaks v8.18 has a behavior where --redact
  # breaks allowlist matching (it redacts the secret before regex match).
  # We redact secrets in our script's display layer instead.
  local gitleaks_args=(--no-banner)
  if [[ -f "${REFERENCES_DIR}/gitleaks.toml" ]]; then
    gitleaks_args+=(--config "${REFERENCES_DIR}/gitleaks.toml")
  fi

  case "$SCAN_TARGET" in
    staged)
      gitleaks_args+=(protect --staged)
      ;;
    all)
      gitleaks_args+=(detect --no-git)
      ;;
    working-tree)
      gitleaks_args+=(detect --source . --no-git)
      ;;
  esac

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[dry-run] gitleaks ${gitleaks_args[*]}"
    return 0
  fi

  local output exit_code
  output="$(gitleaks "${gitleaks_args[@]}" 2>&1)" || exit_code=$?
  exit_code="${exit_code:-0}"

  if [[ ${exit_code} -eq 0 ]]; then
    return 0  # clean
  fi

  # gitleaks returned non-zero: print output and exit with CRITICAL (1)
  # Redact secret values in display (keep file/line/rule for actionable info)
  local display_output
  display_output="$(echo "${output}" \
    | sed -E 's/Secret:[[:space:]]+.*/Secret: ***REDACTED***/g')"

  if is_json_mode; then
    echo "{\"tool\":\"gitleaks\",\"target\":\"${SCAN_TARGET}\",\"findings\":[],\"raw\":\"$(echo "${display_output}" | sed 's/"/\\"/g' | tr '\n' ' ')\"}"
  else
    log_err "gitleaks detected secrets:
${display_output}

Fix: remove secrets, rotate them, add files to .gitignore, or use a secret manager.
Override: HIGH findings can be suppressed with 'gitleaks:allow' in commit message."
  fi
  exit 1
}

# ----- Scan with embedded rules -----
scan_with_embedded() {
  log_info "Using embedded rules (fallback)..."

  local findings=()
  local critical_count=0
  local high_count=0
  local low_count=0

  # Layer 1: Filename scan
  local files
  files="$(get_files)"

  if [[ -n "${files}" ]]; then
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      while IFS= read -r rule; do
        [[ -z "$rule" ]] && continue
        local sev="${rule%%|*}"
        local pattern="${rule#*|}"
        if severity_matches "$sev" "$SEVERITY_FILTER" && matches_glob "$file" "$pattern"; then
          findings+=("{\"severity\":\"${sev}\",\"file\":\"${file}\",\"match\":\"filename match: ${pattern}\",\"rule\":\"filename:${pattern}\"}")
          case "$sev" in
            critical) ((critical_count++)) ;;
            high)     ((high_count++)) ;;
            low)      ((low_count++)) ;;
          esac
        fi
      done < <(printf '%s\n' "${EMBEDDED_FILE_RULES[@]}")
    done < <(printf '%s\n' "${files}")
  fi

  # Layer 2: Content scan (only for files in scan target)
  if [[ -n "${files}" ]]; then
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue

      # Skip excluded paths for content rules
      case "$file" in
        *.example|*.sample|*.template|*.test|*.fixture|*.md|LICENSE|.gitignore)
          continue
          ;;
      esac

      local content
      content="$(get_diff_content "$file")"
      [[ -z "$content" ]] && continue

      while IFS= read -r rule; do
        [[ -z "$rule" ]] && continue
        local sev="${rule%%|*}"
        local rest="${rule#*|}"
        local name="${rest%%|*}"
        local regex="${rest#*|}"

        if ! severity_matches "$sev" "$SEVERITY_FILTER"; then
          continue
        fi

        if [[ "${DRY_RUN}" == "true" ]]; then
          continue
        fi

        local match
        if match="$(printf '%s' "${content}" | grep -oE "${regex}" 2>/dev/null | head -n 1)"; then
          [[ -z "$match" ]] && continue
          findings+=("{\"severity\":\"${sev}\",\"file\":\"${file}\",\"match\":\"${match:0:30}...\",\"rule\":\"${name}\"}")
          case "$sev" in
            critical) ((critical_count++)) ;;
            high)     ((high_count++)) ;;
            low)      ((low_count++)) ;;
          esac
        fi
      done < <(printf '%s\n' "${EMBEDDED_CONTENT_RULES[@]}")
    done < <(printf '%s\n' "${files}")
  fi

  # ----- Output -----
  if is_json_mode; then
    if [[ ${#findings[@]} -eq 0 ]]; then
      echo "{\"tool\":\"embedded\",\"target\":\"${SCAN_TARGET}\",\"findings\":[]}"
    else
      local findings_json
      findings_json="$(IFS=,; echo "${findings[*]}")"
      echo "{\"tool\":\"embedded\",\"target\":\"${SCAN_TARGET}\",\"findings\":[${findings_json}]}"
    fi
  else
    if [[ ${#findings[@]} -eq 0 ]]; then
      log_ok "No secrets detected in ${SCAN_TARGET}."
      return 0
    fi
    log_warn "Found ${#findings[@]} potential secret(s) in ${SCAN_TARGET}:"
    for f in "${findings[@]}"; do
      # Parse JSON for human display
      local sev file rule
      sev="$(echo "$f" | sed -n 's/.*"severity":"\([^"]*\)".*/\1/p')"
      file="$(echo "$f" | sed -n 's/.*"file":"\([^"]*\)".*/\1/p')"
      rule="$(echo "$f" | sed -n 's/.*"rule":"\([^"]*\)".*/\1/p')"
      case "$sev" in
        critical) log_err "[CRITICAL] ${file}: ${rule}" ;;
        high)     log_warn "[HIGH]     ${file}: ${rule}" ;;
        low)      log_info "[LOW]      ${file}: ${rule}" ;;
      esac
    done
  fi

  # ----- Exit code decision -----
  if [[ $critical_count -gt 0 ]]; then
    if ! is_json_mode; then
      log_err "
${critical_count} CRITICAL finding(s) cannot be bypassed.
Fix: rotate the secret, remove from history, or move to .gitignore."
    fi
    exit 1
  fi

  if [[ $high_count -gt 0 ]]; then
    if [[ "${FORCE_ALLOW_HIGH}" == "true" ]]; then
      if ! is_json_mode; then
        log_warn "${high_count} HIGH finding(s) BYPASSED with --force-allow-high."
      fi
      exit 3
    fi
    if ! is_json_mode; then
      log_err "${high_count} HIGH finding(s). Use --force-allow-high to override."
    fi
    exit 2
  fi

  if [[ $low_count -gt 0 ]]; then
    if ! is_json_mode; then
      log_warn "${low_count} LOW warning(s) only. Continuing."
    fi
    exit 0
  fi

  exit 0
}

# ----- Main -----
if [[ "${USE_GITLEAKS_AUTO}" == "true" ]] && has_cmd gitleaks; then
  scan_with_gitleaks
  # gitleaks handles its own exit; if clean exit 0, if findings exit 1
else
  scan_with_embedded
fi