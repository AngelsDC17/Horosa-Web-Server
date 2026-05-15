#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "${ROOT}/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "${ROOT}/.env"
  set +a
fi

HOROSA_SERVER_HOST="${HOROSA_SERVER_HOST:-127.0.0.1}"
HOROSA_SERVER_PORT="${HOROSA_SERVER_PORT:-9999}"
HOROSA_CHART_HOST="${HOROSA_CHART_HOST:-127.0.0.1}"
HOROSA_CHART_PORT="${HOROSA_CHART_PORT:-8899}"

echo "Checking chart service..."
curl --connect-timeout 3 --max-time 5 -fsS "http://${HOROSA_CHART_HOST}:${HOROSA_CHART_PORT}/" >/dev/null

echo "Checking API port..."
curl --connect-timeout 3 --max-time 5 -fsS "http://${HOROSA_SERVER_HOST}:${HOROSA_SERVER_PORT}/common/time" >/dev/null || {
  echo "API is reachable only through signed frontend requests, or /common/time rejected unsigned curl."
  echo "Port check fallback:"
  if command -v nc >/dev/null 2>&1; then
    nc -z -G 3 "${HOROSA_SERVER_HOST}" "${HOROSA_SERVER_PORT}" 2>/dev/null ||
      nc -z -w 3 "${HOROSA_SERVER_HOST}" "${HOROSA_SERVER_PORT}"
  else
    bash -c ":</dev/tcp/${HOROSA_SERVER_HOST}/${HOROSA_SERVER_PORT}"
  fi
}

echo "Horosa web services look reachable."
