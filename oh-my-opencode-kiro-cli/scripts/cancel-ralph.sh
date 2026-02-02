#!/usr/bin/env bash
set -euo pipefail
pids=$(pgrep -f "ralph-loop")
ulw=$(pgrep -f "ulw-loop")
status=0
if [[ -n "${pids:-}" ]]; then
  echo "[cancel-ralph] killing ralph-loop processes: $pids" >&2
  kill $pids || true
else
  echo "[cancel-ralph] no active ralph-loop processes found" >&2
  status=1
fi
if [[ -n "${ulw:-}" ]]; then
  echo "[cancel-ralph] killing ulw-loop processes: $ulw" >&2
  kill $ulw || true
fi
exit $status
