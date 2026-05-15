#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_DIR="${ROOT}/pids"

for name in api chart; do
  pid_file="${PID_DIR}/${name}.pid"
  if [ -f "${pid_file}" ]; then
    pid="$(cat "${pid_file}")"
    if kill -0 "${pid}" >/dev/null 2>&1; then
      kill "${pid}" || true
      echo "Stopped ${name} (${pid})"
    fi
    rm -f "${pid_file}"
  fi
done
