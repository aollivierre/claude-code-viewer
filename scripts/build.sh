#!/usr/bin/env bash

set -euxo pipefail

if ! command -v pnpm >/dev/null 2>&1; then
  echo "error: pnpm not on PATH. Refusing to run — would rm -rf dist then fail." >&2
  echo "hint: run from PowerShell after adding Node 24 to PATH, not directly from Git Bash." >&2
  exit 127
fi

if [ -d "dist" ]; then
  rm -rf dist
fi

pnpm lingui:compile
pnpm build:frontend
pnpm build:backend

cp -r ./src/server/lib/db/migrations ./dist
