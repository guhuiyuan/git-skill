# Gitee Platform Notes

Gitee (码云) is a Chinese Git hosting platform, dominant in China with ~14M developers and ~40M repositories. This skill supports Gitee as a first-class peer to GitHub.

## GitHub vs Gitee: Key Differences

| Dimension | GitHub | Gitee |
|---|---|---|
| **Domain** | github.com, *.ghe.com | gitee.com |
| **Default branch** (created post-2020) | `main` | `master` (still default in 2026) |
| **API style** | REST + GraphQL | REST only |
| **Auth header** | `Authorization: token <PAT>` | Query parameter: `?access_token=<PAT>` |
| **Token prefix (classic)** | `ghp_`, `gho_`, etc. | 32 hex chars (no prefix) |
| **OAuth CLI** | `gh` (official) | `gitee` (official, oschina/gitee-cli) |
| **Issue resource** | `/issues` | `/issues` |
| **PR resource** | `/pulls` | `/pulls` (NOT `/pull_request`) |
| **PR state values** | `open` / `closed` / `merged` | `open` / `closed` / `merged` |
| **Issue labels** | Dedicated labels API (`/labels`) | Combined into issue body (no separate labels endpoint) |
| **Webhooks** | Full support | Partial |
| **CI/CD** | GitHub Actions | Gitee Go |
| **Pull request comments** | Inline + general | Inline + general |
| **Wiki** | Per-repo (deprecated for many) | Per-repo, active |

## Authentication

GitHub: `gh auth login` (OAuth, secure)
Gitee: `gitee auth login` (Personal Access Token or OAuth)

**Token scopes for Gitee** (minimum required by this skill):

- `user_info` — read/update profile
- `projects` — create repos, push, pull
- `pull_requests` — create / merge PRs
- `issues` — create / comment issues

For details, see [auth-guide.md](auth-guide.md).

## CLI Equivalence

| Action | GitHub (`gh`) | Gitee (`gitee`) |
|---|---|---|
| Auth status | `gh auth status` | `gitee auth status` |
| Create repo | `gh repo create` | `gitee repo create` |
| List issues | `gh issue list` | `gitee issue list` |
| Create issue | `gh issue create` | `gitee issue create` |
| List PRs | `gh pr list` | `gitee pr list` |
| Create PR | `gh pr create` | `gitee pr create` |
| View PR | `gh pr view` | `gitee pr view` |

## API Endpoints

| Action | GitHub REST | Gitee REST |
|---|---|---|
| Create user repo | `POST /user/repos` | `POST /api/v5/user/repos` |
| Create org repo | `POST /orgs/{org}/repos` | `POST /api/v5/orgs/{org}/repos` |
| List issues | `GET /repos/{owner}/{repo}/issues` | `GET /api/v5/repos/{owner}/{repo}/issues` |
| Create issue | `POST /repos/{owner}/{repo}/issues` | `POST /api/v5/repos/{owner}/{repo}/issues` |
| List PRs | `GET /repos/{owner}/{repo}/pulls` | `GET /api/v5/repos/{owner}/{repo}/pulls` |
| Create PR | `POST /repos/{owner}/{repo}/pulls` | `POST /api/v5/repos/{owner}/{repo}/pulls` |

## Authentication header differences

**GitHub**:
```bash
curl -H "Authorization: token ghp_xxxx" \
     https://api.github.com/user
```

**Gitee**:
```bash
curl "https://gitee.com/api/v5/user?access_token=<32-hex-token>"
```

## Default branch gotcha

When creating a repo on Gitee via API, the default branch is `master`. On GitHub (post-2020), it's `main`. This skill handles both automatically:

```bash
/git init                # Local: prompts for branch (default main)
/git create-repo --platform github|gitee  # Auto-detects platform default
/git push -u origin main  # GitHub push
/git push -u origin master  # Gitee push (note: master!)
```

## Token format

**GitHub tokens** have prefixes that make them identifiable:

- `ghp_` (Personal Access Token)
- `gho_` (OAuth)
- `ghu_` (User token)
- `ghs_` (Server token)
- `ghr_` (Refresh token)
- `github_pat_` (Fine-grained PAT)

**Gitee tokens** are 32-character hex strings with **no prefix**. This makes them harder to detect via regex. The gitleaks rules in this skill do NOT have a specific Gitee pattern by default — add your own if you regularly use Gitee.

## Why Gitee first-class support

- ~14M Chinese developers, ~40M repos
- 42% of Chinese agile teams use Gitee (信通院 data)
- Required by some government / enterprise compliance
- Better performance for users in China (no GitHub connectivity issues)

## Quick comparison

```bash
# Same skill verb, different platform:

# Create on GitHub
/git create-repo --platform github --name my-app --public --description "My app"

# Create on Gitee
/git create-repo --platform gitee --name my-app --public --description "My app"

# Both: skill detects CLI presence (gh / gitee), falls back to REST API + env var
```

## References

- Gitee Open API docs: <https://gitee.com/api/v5/swagger>
- oschina/gitee-cli: <https://gitee.com/oschina/gitee-cli>