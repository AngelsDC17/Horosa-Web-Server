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
export NODE_OPTIONS="${NODE_OPTIONS:---openssl-legacy-provider}"

npm ci
npm run build

echo "Frontend built at ${ROOT}/astrostudyui/dist"
