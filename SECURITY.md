# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this skill, please email **security@example.com** (replace with actual address when deploying) instead of using the issue tracker.

We will acknowledge receipt within 48 hours and aim to provide a fix within 7 days for critical issues.

## Reporting False Positives in Secret Scanning

If the skill's secret scanner (gitleaks or embedded rules) flags a non-secret pattern as a secret:

1. **Do NOT include the actual secret** in your report
2. Include only:
   - The pattern that was matched (e.g., `AWS_ACCESS_KEY_ID=AKIA...`)
   - A SHA-256 hash of the file (not the file contents)
   - Why you believe it is a false positive
3. Open an issue with label `false-positive`

## Sensitive Information

**Never commit secrets to this repository.** If you accidentally do:

1. Rotate the secret immediately (do not wait for response)
2. Use `git filter-repo` or BFG to remove from history
3. Force-push (or, for already-public repos, accept the leak and rotate)
4. Open an issue describing the situation (without the secret)

## Token Storage

This skill **requires** you to store tokens in your OS keychain. We do not recommend:

- :x: Tokens in `.zshrc` / `.bashrc` (visible to AI agents, often leaked)
- :x: Inline tokens in shell commands (go to shell history)
- :x: Tokens in commit messages or README files
- :x: Tokens in CI logs

Recommended:

- :white_check_mark: OS Keychain (macOS Keychain / Windows Credential Manager / Linux libsecret)
- :white_check_mark: 1Password CLI / Bitwarden CLI for cross-device
- :white_check_mark: Platform Secrets for CI/CD

## Skill Permissions

The skill's `allowed-tools` is configured to limit blast radius:

- :white_check_mark: `Bash(git:*)` — git operations
- :white_check_mark: `Bash(gh:*)`, `Bash(gitee:*)`, `Bash(gitleaks:*)` — CLI tools
- :white_check_mark: `WebFetch(domain:github.com,gitee.com,...)` — platform APIs only
- :x: No `Bash(rm:*)`, `Bash(sudo:*)`, or `WebSearch` (anti-exfiltration)

If you find a way to exfiltrate data using these allowed tools, please report it.