#!/usr/bin/env bash
# Initialize a target repo for team-agent-playbook sync.
#
# Drops in the SPEC.md skeleton (if missing) and ensures AGENTS.local.md is
# git-ignored. The first sync workflow run will then create AGENTS.md,
# CLAUDE.md, and .gemini/settings.json via PR.
#
# Usage: init.sh <target_repo_path>

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <target_repo_path>" >&2
    exit 2
fi

TARGET="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../templates"

if [[ ! -d "$TARGET" ]]; then
    echo "error: $TARGET is not a directory" >&2
    exit 1
fi

# 1. Copy SPEC.md skeleton (only if missing).
if [[ -e "$TARGET/SPEC.md" ]]; then
    echo "skip: $TARGET/SPEC.md already exists"
else
    cp "$TEMPLATE_DIR/SPEC.md" "$TARGET/SPEC.md"
    echo "created: $TARGET/SPEC.md (skeleton — fill in or have an LLM draft)"
fi

# 2. Ensure AGENTS.local.md is in .gitignore.
GITIGNORE="$TARGET/.gitignore"
ENTRY="AGENTS.local.md"

if [[ -f "$GITIGNORE" ]] && grep -qxF "$ENTRY" "$GITIGNORE"; then
    echo "skip: $ENTRY already in .gitignore"
else
    if [[ -f "$GITIGNORE" ]] && [[ -n "$(tail -c 1 "$GITIGNORE")" ]]; then
        echo "" >> "$GITIGNORE"
    fi
    echo "$ENTRY" >> "$GITIGNORE"
    echo "added: $ENTRY to $GITIGNORE"
fi

cat <<'EOF'

Next steps:
  1. Commit and push these changes to the target repo.
  2. Add the topic `team-agent-playbook-managed` to the repo:
       gh repo edit <org>/<repo> --add-topic team-agent-playbook-managed
     (or via Settings → Topics on github.com)
  3. Run the sync workflow in your org's team-agent-playbook fork
     (Actions → Sync AGENTS.md → Run workflow).
  4. Review and merge the resulting PR to adopt the team standards.
EOF
