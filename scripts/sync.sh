#!/usr/bin/env bash
# Sync the playbook's base files into every opt-in target repo, opening one PR
# per repo. Target repos are discovered via the `team-agent-playbook-managed`
# topic on the same org as this workflow lives in (i.e. the fork's owner).
#
# Per-repo failures produce GitHub Actions warnings but do not stop the loop;
# the script exits 1 if any repo failed.
#
# Required env:
#   GH_TOKEN     PAT with write access to each target repo
#   ORG          GitHub org/owner to scan (e.g. ${{ github.repository_owner }})
#   SOURCE_SHA   full source commit hash (e.g. ${{ github.sha }})
# Optional env:
#   SOURCE_REPO  source repo slug for PR body (defaults to "team-agent-playbook")

set -uo pipefail

PLAYBOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_AGENTS="$PLAYBOOK_DIR/base/AGENTS.md"
BASE_CLAUDE="$PLAYBOOK_DIR/base/CLAUDE.md"
BASE_GEMINI="$PLAYBOOK_DIR/base/.gemini/settings.json"

: "${GH_TOKEN:?GH_TOKEN required}"
: "${ORG:?ORG required}"
: "${SOURCE_SHA:?SOURCE_SHA required}"
SOURCE_REPO="${SOURCE_REPO:-team-agent-playbook}"

MANAGED_TOPIC="team-agent-playbook-managed"

SHORT_SHA="${SOURCE_SHA:0:7}"
BRANCH="chore/sync-agents-${SHORT_SHA}"
PR_TITLE="chore: sync AGENTS.md base (commit ${SHORT_SHA})"

git config --global user.email "github-actions[bot]@users.noreply.github.com"
git config --global user.name "github-actions[bot]"

# sync_repo runs the full sync for one target repo. It is invoked inside a
# subshell so that `set -e` failures abort only this repo, not the whole loop.
sync_repo() {
    local repo="$1"
    local workdir
    workdir="$(mktemp -d)"
    trap "rm -rf '$workdir'" EXIT

    set -e
    echo "::group::Sync ${repo}"

    git clone --depth 1 --quiet \
        "https://x-access-token:${GH_TOKEN}@github.com/${repo}.git" \
        "${workdir}/repo"
    cd "${workdir}/repo"

    local default_branch
    default_branch="$(git rev-parse --abbrev-ref HEAD)"
    git checkout -b "$BRANCH"

    # A. AGENTS.md
    local agents_rc=0
    python3 "${PLAYBOOK_DIR}/scripts/update_base_section.py" \
        AGENTS.md "$BASE_AGENTS" --commit "$SOURCE_SHA" || agents_rc=$?
    if [[ $agents_rc -eq 1 ]]; then
        echo "::warning::${repo}: AGENTS.md exists without TEAM-BASE markers; skipping repo"
        echo "::endgroup::"
        return 0
    fi
    if [[ $agents_rc -ne 0 ]]; then
        echo "::error::${repo}: update_base_section.py exited ${agents_rc}"
        echo "::endgroup::"
        return 1
    fi

    # B. CLAUDE.md — ensure first line is `@AGENTS.md`.
    if [[ ! -f CLAUDE.md ]]; then
        cp "$BASE_CLAUDE" CLAUDE.md
    else
        local first_line
        first_line="$(head -n 1 CLAUDE.md || true)"
        if [[ "$first_line" != "@AGENTS.md" ]]; then
            grep -vxF "@AGENTS.md" CLAUDE.md > CLAUDE.md.new || true
            { echo "@AGENTS.md"; echo ""; cat CLAUDE.md.new; } > CLAUDE.md
            rm -f CLAUDE.md.new
        fi
    fi

    # C. .gemini/settings.json
    mkdir -p .gemini
    python3 "${PLAYBOOK_DIR}/scripts/merge_gemini_settings.py" \
        .gemini/settings.json "$BASE_GEMINI"

    git add AGENTS.md CLAUDE.md .gemini/settings.json
    if git diff --cached --quiet; then
        echo "${repo}: no changes; skipping PR"
        echo "::endgroup::"
        return 0
    fi

    git commit -m "$PR_TITLE" \
               -m "Auto-synced from ${SOURCE_REPO} (${SHORT_SHA})."
    git push -u origin "$BRANCH"

    gh pr create \
        --repo "$repo" \
        --base "$default_branch" \
        --head "$BRANCH" \
        --title "$PR_TITLE" \
        --body "Auto-synced from \`${SOURCE_REPO}\` (commit \`${SHORT_SHA}\`).

Updated:
- \`AGENTS.md\` (TEAM-BASE block)
- \`CLAUDE.md\` (\`@AGENTS.md\` import on first line)
- \`.gemini/settings.json\` (\`context.fileName\` includes \`AGENTS.md\`)

Review the diff and merge to adopt the latest team standards."

    echo "::endgroup::"
    return 0
}

# Discover target repos: $ORG members carrying $MANAGED_TOPIC, excluding
# archived repos (which can't accept PRs anyway).
echo "Discovering repos with topic '${MANAGED_TOPIC}' in org '${ORG}'..."
if ! REPO_INPUT="$(gh search repos \
        --topic "$MANAGED_TOPIC" \
        --owner "$ORG" \
        --limit 1000 \
        --json nameWithOwner,isArchived \
        --jq '[.[] | select(.isArchived == false)] | .[].nameWithOwner')"; then
    echo "::error::failed to discover repos via gh search"
    exit 1
fi

mapfile -t REPOS < <(echo "$REPO_INPUT" | sed '/^$/d')

if [[ ${#REPOS[@]} -eq 0 ]]; then
    echo "::warning::no target repos found (topic '${MANAGED_TOPIC}' not set on any non-archived repo in '${ORG}')"
    exit 0
fi

echo "Will sync ${#REPOS[@]} repo(s):"
printf '  %s\n' "${REPOS[@]}"

OVERALL_RC=0
for REPO in "${REPOS[@]}"; do
    if ! ( sync_repo "$REPO" ); then
        echo "::warning::sync failed for ${REPO}"
        OVERALL_RC=1
    fi
done

exit "$OVERALL_RC"
