#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "${ROOT}/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "${ROOT}/.env"
  set +a
fi

cd "${ROOT}/astrostudyui"

export HOROSA_PUBLIC_SERVER_ROOT="${HOROSA_PUBLIC_SERVER_ROOT:-/api}"
export HOROSA_PUBLIC_PATH="${HOROSA_PUBLIC_PATH:-/}"
export HOROSA_LOW_MEMORY_BUILD="${HOROSA_LOW_MEMORY_BUILD:-1}"
export NODE_OPTIONS="${NODE_OPTIONS:---openssl-legacy-provider --max-old-space-size=640}"

npm ci --ignore-scripts --no-audit --no-fund
node scripts/patch_quill_domnodeinserted.js
npm run build:digitalocean

echo "Frontend built at ${ROOT}/astrostudyui/dist"
