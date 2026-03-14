#!/usr/bin/env bash
# Remove all temporary files created during the action run.
set -euo pipefail

rm -rf /tmp/specs /tmp/scripts /tmp/drift-diff.json \
       /tmp/drift-base-worktree /tmp/drift-agent-clones \
       /tmp/swag-docs
rm -f ./.drift-nestjs-gen.ts
echo "[drift-agent] cleanup done"
