#!/usr/bin/env bash
set -euo pipefail

goal=${1:-}
if [[ -z "$goal" ]]; then
  echo "Usage: $0 \"goal text\" [--completion-promise=STRING] [--max-iterations=N] [--agent=NAME] [--model=ID]" >&2
  exit 1
fi
shift || true
completion_promise="<promise>DONE</promise>"
max_iterations=100
agent="ultrawork-runner"
model=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --completion-promise=*) completion_promise="${1#*=}" ;;
    --max-iterations=*) max_iterations="${1#*=}" ;;
    --agent=*) agent="${1#*=}" ;;
    --model=*) model="${1#*=}" ;;
    *) echo "Unknown flag: $1" >&2 ; exit 1 ;;
  esac
  shift
done

echo "[ulw-loop] ultrawork mode goal=$goal agent=$agent max_iterations=$max_iterations" >&2
iter=1
while (( iter <= max_iterations )); do
  echo "[ulw-loop] iteration $iter" >&2
  tmp=$(mktemp)
  if [[ -n "$model" ]]; then
    ULTRAWORK=1 kiro-cli chat --agent "$agent" --model "$model" --message "[ultrawork mode] $goal" | tee "$tmp"
  else
    ULTRAWORK=1 kiro-cli chat --agent "$agent" --message "[ultrawork mode] $goal" | tee "$tmp"
  fi
  if grep -qi "$completion_promise" "$tmp"; then
    echo "[ulw-loop] completion promise detected: $completion_promise" >&2
    rm "$tmp"
    exit 0
  fi
  if grep -qi "<promise>DONE</promise>" "$tmp"; then
    echo "[ulw-loop] completion promise detected via <promise>DONE</promise>" >&2
    rm "$tmp"
    exit 0
  fi
  rm "$tmp"
  iter=$((iter+1))
  sleep 1
done
echo "[ulw-loop] reached max iterations ($max_iterations) without completion" >&2
exit 2
