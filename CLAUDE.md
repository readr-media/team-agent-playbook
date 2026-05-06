# CLAUDE.md

Project-scoped rules for **team-agent-playbook** — the canonical for cross-tool team coding standards.

## What this repo does

Maintains `base/AGENTS.md` and bridge files (`base/CLAUDE.md`, `base/.gemini/settings.json`) that get synced to every opted-in team repo via GitHub Actions. See [SPEC.md](SPEC.md) for architecture and [README.md](README.md) for usage.

## Working in this repo

- `base/**` and `scripts/**` changes trigger the sync workflow on push to `main`.
- `templates/**` is one-time scaffold — not synced after a target repo's first init.
- Editing `base/AGENTS.md` propagates to every target repo on next sync — review with care.
- Use `[BREAKING]` prefix in PR title for changes that invalidate existing `## Project Customization` sections (e.g. marker syntax change).

## Run / test

| Command | Purpose |
|---|---|
| `python3 scripts/update_base_section.py <target> base/AGENTS.md --commit <hash>` | Replace TEAM-BASE region in a target file. Exit 1 if target has no markers. |
| `python3 scripts/merge_gemini_settings.py <target> base/.gemini/settings.json` | Merge `.gemini/settings.json`, preserving existing keys. |
| `bash scripts/init.sh <target_repo_path>` | One-time scaffold for a new target repo. |
| `bash scripts/sync.sh` | Per-repo orchestrator. Only runs in GitHub Actions (requires `GH_TOKEN`, `ORG`, `SOURCE_SHA`). |

## Conventions

- AI-facing docs (`CLAUDE.md`, `SPEC.md`, `base/AGENTS.md`, `templates/SPEC.md`) — English (per `~/.claude/CLAUDE.md` Doc Language).
- Human-facing docs (`README.md`) — Traditional Chinese (Taiwan), per the team audience.
- Conventional commits (`feat:` / `fix:` / `chore:` / `docs:` / `refactor:` / `test:` / `style:` / `perf:`).
- Never auto-commit; user approval required.
- Never force-push to `main`.

## Branch protection (canonical)

`main` requires ≥1 PR review.

## Auth

Sync workflow authenticates as a **GitHub App** (org-installed). Variables/secrets:
- Variable `SYNC_APP_CLIENT_ID` — App's Client ID
- Secret `SYNC_APP_PRIVATE_KEY` — App's `.pem` content

The workflow exchanges these for a short-lived installation token via `actions/create-github-app-token@v1` and passes it to `sync.sh` as `GH_TOKEN`. See [SPEC.md](SPEC.md) → "Authentication" for rationale.
