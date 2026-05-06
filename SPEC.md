# team-agent-playbook — Spec

Architecture and design notes for AI agents working on this repo.

## Purpose

Maintain a single canonical source of team-wide AGENTS.md standards, automatically synced into every team repo via GitHub Actions. Cross-tool: Claude Code, Gemini CLI, Codex CLI, Cursor.

## Hosting Architecture

```
readr-media/team-agent-playbook       canonical (public)
  ├─ mirror-media/team-agent-playbook fork
  ├─ mirror-tv/team-agent-playbook    fork
  └─ mirrordaily/team-agent-playbook  fork
```

Each fork runs its own sync workflow with that org's PAT. PATs never cross org boundaries — security and ownership stay clean.

## Layout

```
base/                           Synced into every target repo
  AGENTS.md                     Team standards (TEAM-BASE markers + Project Customization)
  CLAUDE.md                     @AGENTS.md import + optional Claude-only rules
  .gemini/settings.json         context.fileName includes AGENTS.md

templates/                      One-time scaffold, NOT synced
  SPEC.md                       Skeleton for project-specific architecture docs

scripts/
  update_base_section.py        Replaces TEAM-BASE region in target AGENTS.md
  merge_gemini_settings.py      JSON merge that preserves existing keys
  sync.sh                       Per-repo orchestrator (called by Action)
  init.sh                       Manual scaffold for new target repos

.github/workflows/sync-agents.yml   Triggers sync on base/** push or workflow_dispatch
```

## Sync Flow

Triggered only by push to `main` that modifies any file under `base/` (the synced template directory). Internal changes (scripts, workflow YAML, docs) do not trigger downstream sync — use `workflow_dispatch` if a manual re-sync is needed.

1. **Discover targets**: `gh search repos --topic team-agent-playbook-managed --owner $ORG`. Archived repos filtered out.
2. **Per repo** (subshell-isolated, failure does not stop the loop):
   a. Clone target with `GH_TOKEN`.
   b. `update_base_section.py AGENTS.md base/AGENTS.md --commit $SHA`.
      - File missing → write full template.
      - File has TEAM-BASE markers → replace region only.
      - File exists without markers → exit 1; sync.sh emits `::warning::` and skips.
   c. Ensure `CLAUDE.md` first line is `@AGENTS.md` (create if missing; move if elsewhere).
   d. `merge_gemini_settings.py .gemini/settings.json base/.gemini/settings.json`.
   e. If anything changed: commit, push branch `chore/sync-agents-<short-hash>`, open PR via `gh pr create`.

PR title: `chore: sync AGENTS.md base (commit <short-hash>)`.

## Boundary Marker Design

`<!-- TEAM-BASE-START -->` / `<!-- TEAM-BASE-END -->` HTML comments delimit the synced region. Chosen over YAML frontmatter because:

- Frontmatter only sits at file start — cannot define a region with paired start/end.
- HTML comments are invisible when rendered but visible to AI tools as text.
- Universal across Markdown parsers; no extension required.

`Last synced: YYYY-MM-DD (commit XXXXXXX)` placeholder text in `base/AGENTS.md` is replaced at sync time by regex in `update_base_section.py`.

## Target Discovery: GitHub Topic

Topic-based opt-in: `team-agent-playbook-managed`. Set via Settings → Topics or `gh repo edit <repo> --add-topic team-agent-playbook-managed`. Archived repos filtered out automatically. No central allowlist.

The canonical (`readr-media/team-agent-playbook`) and forks **must not** carry the topic — they would attempt to sync to themselves.

## Cross-Tool Bridges

| Tool        | Reads AGENTS.md natively? | Bridge file in target repo |
|-------------|---------------------------|----------------------------|
| Codex CLI   | Yes                       | None                       |
| Cursor      | Yes (v2.2+)               | None                       |
| Claude Code | No                        | `CLAUDE.md` first line `@AGENTS.md` |
| Gemini CLI  | No (configurable)         | `.gemini/settings.json` with `context.fileName: ["AGENTS.md", "GEMINI.md"]` |

## Authentication

The sync workflow authenticates as a **GitHub App** installed on the org. The workflow exchanges the App's private key for a short-lived (1-hour) installation token via `actions/create-github-app-token@v1`, which is passed to `sync.sh` as `GH_TOKEN`.

- **Variable** `SYNC_APP_CLIENT_ID` — the App's Client ID (e.g. `Iv23xxxxxxxxxxxxxxxx`)
- **Secret** `SYNC_APP_PRIVATE_KEY` — the App's `.pem` private key (full content)

Why GitHub App over PAT:
- Tokens auto-rotate per workflow run; no manual yearly rotation
- Decoupled from any individual maintainer's account lifecycle
- Permissions managed at org level, not user level

Each fork's Action runs with its own org's App. PAT-equivalent leakage scope is one workflow run (≤ 1 hour token TTL).

## Conventions

- Shebangs: `#!/usr/bin/env bash` and `#!/usr/bin/env python3`.
- Per-repo errors in `sync.sh` use `::warning::` / `::error::` annotations; the loop continues regardless.
- Branch name for sync PR: `chore/sync-agents-<short-hash>`.
- `[BREAKING]` prefix in PR title when a change invalidates existing `## Project Customization` sections (e.g. marker syntax change).

## Verification

- **Local fixture tests**: `update_base_section.py` and `merge_gemini_settings.py` each cover three scenarios (no file / has marker or partial / no marker or fully populated). Run ad-hoc with `mktemp -d` fixtures.
- **End-to-end**: trigger sync workflow against a pilot target repo, verify the PR contains the expected file changes.

## Known Limitations / Non-goals

- The Action does not auto-merge PRs; merge is human-driven.
- `templates/SPEC.md` is one-shot scaffold (not synced after init); each repo maintains its own SPEC.md from then on.
- TEAM-BASE markers manually removed from a target repo's `AGENTS.md` cause subsequent syncs to skip with a warning. This is intentional (manual recovery required).

## Key Decisions

- **Topic-based discovery, not central allowlist**: removed `TARGET_REPOS` variable in favor of `team-agent-playbook-managed` topic. Rationale: zero central maintenance; opt-in is discoverable in repo UI; opt-out is removing the topic.
- **Fork-per-org, not single canonical with cross-org PAT**: each org's Action uses its own scoped PAT. Rationale: tighter security boundary, org autonomy, decoupling from individual maintainer's account lifecycle.
- **HTML comment markers, not YAML frontmatter**: see "Boundary Marker Design".
- **Sync replaces only the TEAM-BASE region**: `## Project Customization` and below is repo-owned; the workflow never touches it.
