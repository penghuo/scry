#!/usr/bin/env bash
set -euo pipefail
plan=${1:-"default"}
kiro-cli chat --agent atlas --message "Execute plan ${plan}"
