#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "${ROOT}/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "${ROOT}/.env"
  set +a
fi

JAVA_BIN="${JAVA_BIN:-java}"
PYTHON_BIN="${PYTHON_BIN:-${ROOT}/.venv/bin/python}"
if [ ! -x "${PYTHON_BIN}" ]; then
  PYTHON_BIN="${PYTHON_BIN_FALLBACK:-python3}"
fi

JAVA_XMS="${HOROSA_JAVA_XMS:-256m}"
JAVA_XMX="${HOROSA_JAVA_XMX:-1024m}"
JAVA_METASPACE="${HOROSA_JAVA_METASPACE:-256m}"
CHART_THREADS="${HOROSA_CHART_THREAD_POOL:-8}"
CHART_HOST="${HOROSA_CHART_HOST:-127.0.0.1}"
CHART_PORT="${HOROSA_CHART_PORT:-18899}"

print_size() {
  local path="$1"
  if [ -e "${path}" ]; then
    du -sh "${path}" | awk '{print $1}'
  else
    echo "missing"
  fi
}

tracked_size_mib() {
  if ! command -v git >/dev/null 2>&1 || ! git -C "${ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "unknown"
    return
  fi
  git -C "${ROOT}" ls-files -z |
    python3 -c 'import os,sys
root=sys.argv[1]
data=sys.stdin.buffer.read().split(b"\0")
total=0
count=0
for raw in data:
    if not raw:
        continue
    path=os.path.join(root, raw.decode("utf-8", "surrogateescape"))
    try:
        total += os.path.getsize(path)
        count += 1
    except OSError:
        pass
print(f"{total/1024/1024:.1f} MiB ({count:,} tracked files)")' "${ROOT}"
}

java_heap_bytes() {
  local opts="$1"
  JAVA_TOOL_OPTIONS="${opts}" "${JAVA_BIN}" -XX:+PrintFlagsFinal -version 2>&1 |
    awk '/MaxHeapSize/ {print $4; exit}'
}

bytes_to_mib() {
  awk -v b="$1" 'BEGIN{printf "%.1f", b / 1024 / 1024}'
}

echo "Horosa web server footprint"
echo "root=${ROOT}"
echo

default_heap="$("${JAVA_BIN}" -XX:+PrintFlagsFinal -version 2>&1 | awk '/MaxHeapSize/ {print $4; exit}')"
tuned_heap="$(java_heap_bytes "-Xms${JAVA_XMS} -Xmx${JAVA_XMX} -XX:MaxMetaspaceSize=${JAVA_METASPACE}")"
echo "Java memory cap"
echo "  default MaxHeapSize: ${default_heap} bytes ($(bytes_to_mib "${default_heap}") MiB)"
echo "  tuned   MaxHeapSize: ${tuned_heap} bytes ($(bytes_to_mib "${tuned_heap}") MiB)"
echo "  tuned   metaspace:   ${JAVA_METASPACE}"
echo

echo "Disk footprint"
echo "  tracked source:      $(tracked_size_mib)"
echo "  working tree total:  $(print_size "${ROOT}")"
echo "  frontend dist:       $(print_size "${ROOT}/astrostudyui/dist")"
echo "  astropy bundle:      $(print_size "${ROOT}/astropy")"
echo "  flatlib bundle:      $(print_size "${ROOT}/flatlib-ctrad2")"
echo

echo "Chart service live RSS"
if ! "${PYTHON_BIN}" - <<'PY' >/dev/null 2>&1
import cherrypy
import jsonpickle
PY
then
  echo "  skipped: Python dependencies are not installed. Run:"
  echo "           python3 -m venv .venv && . .venv/bin/activate"
  echo "           pip install cherrypy jsonpickle pyswisseph && pip install -e flatlib-ctrad2"
  exit 0
fi

export PYTHONPATH="${ROOT}/astropy:${ROOT}/flatlib-ctrad2:${PYTHONPATH:-}"
export HOROSA_CHART_HOST="${CHART_HOST}"
export HOROSA_CHART_PORT="${CHART_PORT}"
export HOROSA_CHART_THREAD_POOL="${CHART_THREADS}"

"${PYTHON_BIN}" "${ROOT}/astropy/websrv/webchartsrv.py" >/tmp/horosa-chart-footprint.log 2>&1 &
pid=$!
cleanup() {
  kill "${pid}" >/dev/null 2>&1 || true
  wait "${pid}" 2>/dev/null || true
}
trap cleanup EXIT

ready=0
for _ in $(seq 1 60); do
  if curl -fsS "http://${CHART_HOST}:${CHART_PORT}/" >/tmp/horosa-chart-footprint.json 2>/dev/null; then
    ready=1
    break
  fi
  if ! kill -0 "${pid}" 2>/dev/null; then
    break
  fi
  sleep 0.25
done

if [ "${ready}" != "1" ]; then
  echo "  failed to start; tail follows:"
  tail -n 20 /tmp/horosa-chart-footprint.log || true
  exit 1
fi

sleep 1
rss_kb="$(ps -o rss= -p "${pid}" 2>/dev/null | tr -d ' ' || true)"
vsz_kb="$(ps -o vsz= -p "${pid}" 2>/dev/null | tr -d ' ' || true)"
thread_count="$(ps -M "${pid}" 2>/dev/null | awk 'NR>1{n++} END{print n+0}')"

echo "  thread_pool:         ${CHART_THREADS}"
echo "  rss:                 ${rss_kb:-0} KiB ($(awk -v r="${rss_kb:-0}" 'BEGIN{printf "%.1f", r / 1024}') MiB)"
echo "  virtual_size:        ${vsz_kb:-0} KiB"
echo "  process_threads:     ${thread_count}"
echo "  health_response:     $(cat /tmp/horosa-chart-footprint.json)"
