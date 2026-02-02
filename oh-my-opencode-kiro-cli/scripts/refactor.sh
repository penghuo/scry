#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target> [--scope=file|module|project] [--strategy=safe|aggressive]" >&2
  exit 1
fi
target=$1; shift || true
scope=""
strategy=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope=*) scope="${1#*=}" ;;
    --strategy=*) strategy="${1#*=}" ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done
msg="/refactor target=${target}"
[[ -n "$scope" ]] && msg+=" scope=${scope}"
[[ -n "$strategy" ]] && msg+=" strategy=${strategy}"
kiro-cli chat --agent hephaestus --message "$msg"
