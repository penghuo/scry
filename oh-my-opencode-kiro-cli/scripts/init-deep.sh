#!/usr/bin/env bash
set -euo pipefail
echo "[init-deep] generating hierarchical AGENTS.md context" >&2
goal=${1:-"Generate hierarchical AGENTS.md files"}
kiro-cli chat --agent sisyphus --message "$goal"
