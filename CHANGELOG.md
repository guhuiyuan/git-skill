# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-09-29

### Added
- Initial release: Git 项目管理 skill for Claude Code
- Platform support: GitHub (gh CLI) + Gitee (oschina/gitee-cli)
- Three-tier secret scanning: CRITICAL / HIGH / LOW
- gitleaks binary integration with embedded fallback (20 patterns)
- PreToolUse hook template for second-layer protection
- Automatic .gitignore generation (Node/Python/Java/Go/Rust/.NET/IDE/OS)
- README / LICENSE template generation (3 README levels, 5 LICENSE types)
- Cross-platform install scripts (bash / PowerShell / CMD)
- OS keychain guidance for token storage
- Platform adapter abstraction (`scripts/_platform/`)
- Natural language and `/git <verb>` dual trigger modes

### Security
- Three-layer protection: gitleaks binary → embedded rules → PreToolUse hook
- Token storage guidance: OS keychain only (no inline, no .zshrc)
- CRITICAL findings are never bypassable

[Unreleased]: https://github.com/<owner>/git-skill/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/<owner>/git-skill/releases/tag/v1.0.0