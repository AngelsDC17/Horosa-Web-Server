#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

export HOROSA_LOW_MEMORY_BUILD="${HOROSA_LOW_MEMORY_BUILD:-1}"
export HOROSA_PUBLIC_SERVER_ROOT="${HOROSA_PUBLIC_SERVER_ROOT:-/api}"
export HOROSA_PUBLIC_PATH="${HOROSA_PUBLIC_PATH:-/}"

if [[ -n "${NODE_OPTIONS:-}" ]]; then
  export NODE_OPTIONS="${NODE_OPTIONS}"
else
  export NODE_OPTIONS="--openssl-legacy-provider --max-old-space-size=640"
fi

umi build
node scripts/inject_initial_chunks.js
