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
JAR="${HOROSA_API_JAR:-${ROOT}/astrostudysrv/astrostudyboot/target/astrostudyboot.jar}"

if [ ! -f "${JAR}" ]; then
  echo "Missing backend jar: ${JAR}" >&2
  echo "Run ./scripts/build_backend.sh first." >&2
  exit 1
fi

HOROSA_SERVER_HOST="${HOROSA_SERVER_HOST:-127.0.0.1}"
HOROSA_SERVER_PORT="${HOROSA_SERVER_PORT:-9999}"
HOROSA_CHART_HOST="${HOROSA_CHART_HOST:-127.0.0.1}"
HOROSA_CHART_PORT="${HOROSA_CHART_PORT:-8899}"

JAVA_XMS="${HOROSA_JAVA_XMS:-256m}"
JAVA_XMX="${HOROSA_JAVA_XMX:-1024m}"
JAVA_METASPACE="${HOROSA_JAVA_METASPACE:-256m}"

export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom -XX:+UseG1GC -Xms${JAVA_XMS} -Xmx${JAVA_XMX} -XX:MaxMetaspaceSize=${JAVA_METASPACE}"
export SPRING_MAIN_LAZY_INITIALIZATION="${SPRING_MAIN_LAZY_INITIALIZATION:-true}"
export HOROSA_ENABLE_STARTUP_CRON="${HOROSA_ENABLE_STARTUP_CRON:-0}"
export HOROSA_ENABLE_STARTUP_TRANSGROUP_INIT="${HOROSA_ENABLE_STARTUP_TRANSGROUP_INIT:-0}"
export needtranslog="${needtranslog:-0}"

exec "${JAVA_BIN}" -jar "${JAR}" \
  --server.address="${HOROSA_SERVER_HOST}" \
  --server.port="${HOROSA_SERVER_PORT}" \
  --astrosrv="http://${HOROSA_CHART_HOST}:${HOROSA_CHART_PORT}" \
  --mongodb.ip="${MONGODB_IP:-127.0.0.1}" \
  --redis.ip="${REDIS_IP:-127.0.0.1}"
