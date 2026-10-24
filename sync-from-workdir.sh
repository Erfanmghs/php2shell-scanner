#!/usr/bin/env bash
# Publish scanner artifacts from the local workdir into the git repo root.
# Skips dev/ validation tooling and other non-ship paths.
set -euo pipefail
SRC="${1:-/workspace/php2shell-scanner}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ ! -d "$SRC" ]]; then
  echo "Workdir missing: $SRC" >&2
  exit 1
fi
for name in scanner.py requirements.txt README.md; do
  if [[ -f "$SRC/$name" ]]; then
    cp -a "$SRC/$name" "$ROOT/$name"
  fi
done
if [[ -f "$SRC/LICENSE" ]]; then
  cp -a "$SRC/LICENSE" "$ROOT/LICENSE"
fi
