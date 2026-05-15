#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "${ROOT}/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "${ROOT}/.env"
  set +a
fi

PYTHON_BIN="${PYTHON_BIN:-${ROOT}/.venv/bin/python}"
if [ ! -x "${PYTHON_BIN}" ]; then
  PYTHON_BIN="${PYTHON_BIN_FALLBACK:-python3}"
fi

export PYTHONPATH="${ROOT}/astropy:${ROOT}/flatlib-ctrad2:${PYTHONPATH:-}"
export HOROSA_CHART_HOST="${HOROSA_CHART_HOST:-127.0.0.1}"
export HOROSA_CHART_PORT="${HOROSA_CHART_PORT:-8899}"
export HOROSA_CHART_THREAD_POOL="${HOROSA_CHART_THREAD_POOL:-8}"

exec "${PYTHON_BIN}" "${ROOT}/astropy/websrv/webchartsrv.py"
