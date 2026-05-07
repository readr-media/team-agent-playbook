<!-- TEAM-BASE-START -->
<!-- Last synced: YYYY-MM-DD (commit XXXXXXX) -->
<!-- Source: readr-media/team-agent-playbook -->
<!-- DO NOT EDIT THIS SECTION MANUALLY. Changes here are overwritten by sync. -->
<!-- For project-specific rules, edit the "Project Customization" section below. -->

# Team Standards

This file defines team-wide standards for code, collaboration, and AI agent behavior. It is synced automatically from `readr-media/team-agent-playbook`. The file is read by Claude Code (via `@AGENTS.md` in `CLAUDE.md`), Gemini CLI (via `.gemini/settings.json`), Codex CLI, Cursor, and other AGENTS.md-aware tools.

## Authority

These rules override default AI tool behaviors. Precedence from lowest to highest:

1. AI tool defaults
2. Team standards (this section, between TEAM-BASE markers)
3. `## Project Customization` (per-repo, below the TEAM-BASE-END marker)
4. `AGENTS.local.md` (developer-local override, git-ignored)

To override a team rule for a specific repo, restate it explicitly in `## Project Customization` with the override clearly stated. Do not rely on silence to imply override.

## PR Standards

- **Title format**: `type(scope): description` (conventional commits). Example: `feat(auth): add OAuth login`.
- **Size**: aim for under 400 lines of changes. Larger PRs should be split unless the change is intrinsically atomic.
- **Description must include**: reason for the change, scope of impact, and how to verify.

## Code Review Standards

- Security and performance issues are blocking — must be addressed before merge.
- Non-blocking suggestions use the `nitpick:` prefix; the author may choose to ignore them.
- Reviewers should respond within three working day; escalate via team chat if blocked.

## Git Workflow

- **Commit message**: follow [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/#specification). Format: `type(scope): description`. Allowed types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `style`, `perf`.
- **Branch naming**: prefix with `feature/`, `fix/`, `chore/`, etc., matching the work type.
- **One commit per logical change**: do not split one feature across multiple commits; do not bundle unrelated changes.
- **Never force-push to shared branches** (e.g. `master`/`main`, `dev`/`develop`, `staging`, `prod`).

## Security

- Never commit secrets, API keys, credentials, or `.env` files. All sensitive values use environment variables or secret managers.
- Treat `.env`, `credentials.json`, private keys, and similar files as sensitive even when local; they belong in `.gitignore`.

## Documentation

- `README` and other top-level docs must accurately describe the current implementation.
- When code changes invalidate documented behavior, update the docs in the same PR.
- Out-of-date docs are bugs — file an issue or fix on the spot.
- **SSOT (single source of truth) files use UPPERCASE filenames** — e.g. `README.md`, `SPEC.md`, `LICENSE`, `CHANGELOG.md`. References must match the filename exactly.
- **Editing SSOT files**: before adding content, verify (1) necessity — not already documented elsewhere; (2) non-duplication with existing content; (3) non-contradiction with existing content. Refactor existing content rather than introduce duplication.

## Agent Behavior Discipline

These rules apply to AI agents (Claude Code, Gemini CLI, Codex CLI, Cursor, etc.) when assisting with code in this repo.

### 1. Plan-first
For non-trivial changes (cross-file edits, schema changes, infra changes, dependency changes), propose a plan and get user approval before making changes. Do not act below 95% confidence; ask follow-up questions instead.

### 2. Tests Are Part of the Plan
Every feature implementation plan must include a verification approach (unit, integration, manual, or E2E). Project-wide coverage is not enforced, but "I haven't thought about how to verify this" is not a complete plan.

### 3. Verify Before Asserting
Do not invent APIs, file paths, function names, or behaviors. When uncertain, read the code or check official documentation. Cite sources when referencing external specs.

### 4. Confirm Destructive Actions
Operations that are hard to undo or affect shared state require explicit user confirmation: `rm -rf`, `git push --force`, `git reset --hard`, dropping migrations, `--no-verify`, deleting branches, dropping database tables, etc. Never bypass safety checks as a shortcut.

### 5. Documentation Reflects Reality
`README` and docs must match the implementation. If a code change makes the docs wrong, update the docs in the same change. This explicitly includes `SPEC.md`, which serves as the authoritative project memory — update it whenever architecture, component layout, conventions, or significant decisions change.

### 6. Commit Discipline
Do not commit automatically — present a summary and wait for explicit user approval. One commit per feature; do not split a single task across multiple commits. Use conventional commit messages.

### 7. Communication Style
Lead with the conclusion. Keep status updates short and direct. When stuck or uncertain, report the obstacle rather than working around it silently.

### 8. Production Operations Require Confirmation
Any action that touches production environments (deploys, migrations, config changes, restarts, queries against prod data, secret rotation, etc.) requires explicit user confirmation — even when the action looks routine. Treat "prod" as a hard boundary, not a default.

<!-- TEAM-BASE-END -->

## Project Customization

<!-- Each repo maintains its own project-specific rules below this line. -->
<!-- The sync workflow does not modify this section. -->
