#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/logs"
PID_DIR="${ROOT}/pids"
mkdir -p "${LOG_DIR}" "${PID_DIR}"

"${ROOT}/scripts/start_chart_service.sh" >"${LOG_DIR}/chart.log" 2>&1 &
echo $! >"${PID_DIR}/chart.pid"

sleep 2

"${ROOT}/scripts/start_api_service.sh" >"${LOG_DIR}/api.log" 2>&1 &
echo $! >"${PID_DIR}/api.pid"

echo "Started Horosa web services."
echo "chart pid: $(cat "${PID_DIR}/chart.pid")"
echo "api pid:   $(cat "${PID_DIR}/api.pid")"
echo "logs:      ${LOG_DIR}"
