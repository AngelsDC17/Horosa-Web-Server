#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/horosa-web}"
PUBLIC_HOST="${PUBLIC_HOST:-_}"
JAVA_XMX="${HOROSA_JAVA_XMX:-1536m}"
CHART_WORKERS="${HOROSA_CHART_THREAD_POOL:-8}"
CHART_MEMORY_HIGH="${HOROSA_CHART_MEMORY_HIGH:-1536M}"
CHART_MEMORY_MAX="${HOROSA_CHART_MEMORY_MAX:-2560M}"
API_MEMORY_HIGH="${HOROSA_API_MEMORY_HIGH:-2048M}"
API_MEMORY_MAX="${HOROSA_API_MEMORY_MAX:-3072M}"
ENABLE_PD_WARMUP="${HOROSA_ENABLE_PD_WARMUP:-0}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root on the Droplet." >&2
  exit 1
fi

if [[ ! -d "${APP_DIR}" ]]; then
  echo "Missing ${APP_DIR}. Upload/extract the Horosa deployment bundle first." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "Waiting for apt/dpkg locks..."
for _ in $(seq 1 120); do
  if ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 &&
     ! fuser /var/lib/dpkg/lock >/dev/null 2>&1 &&
     ! fuser /var/cache/apt/archives/lock >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

apt-get update
apt-get install -y \
  ca-certificates \
  curl \
  docker.io \
  netcat-openbsd \
  nginx \
  openjdk-17-jre-headless \
  python3 \
  python3-pip \
  python3-venv

systemctl enable --now docker

docker rm -f horosa-mongo >/dev/null 2>&1 || true
docker run -d \
  --name horosa-mongo \
  --restart unless-stopped \
  -p 127.0.0.1:27017:27017 \
  -v horosa-mongo-data:/data/db \
  mongo:7 \
  --wiredTigerCacheSizeGB 0.25 \
  --bind_ip_all

docker rm -f horosa-redis >/dev/null 2>&1 || true
docker run -d \
  --name horosa-redis \
  --restart unless-stopped \
  -p 127.0.0.1:6379:6379 \
  redis:7-alpine \
  redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru --save ""

cd "${APP_DIR}"

cat > "${APP_DIR}/.env" <<ENV
HOROSA_DOMAIN=${PUBLIC_HOST}
HOROSA_SERVER_HOST=127.0.0.1
HOROSA_SERVER_PORT=9999
HOROSA_CHART_HOST=127.0.0.1
HOROSA_CHART_PORT=8899
HOROSA_PUBLIC_SERVER_ROOT=/api
HOROSA_JAVA_XMS=128m
HOROSA_JAVA_XMX=${JAVA_XMX}
HOROSA_JAVA_METASPACE=192m
HOROSA_CHART_THREAD_POOL=${CHART_WORKERS}
HOROSA_ENABLE_PD_WARMUP=${ENABLE_PD_WARMUP}
MONGODB_IP=127.0.0.1
REDIS_IP=127.0.0.1
HOROSA_ENABLE_STARTUP_CRON=0
HOROSA_ENABLE_STARTUP_TRANSGROUP_INIT=0
needtranslog=0
ENV

python3 -m venv "${APP_DIR}/.venv"
"${APP_DIR}/.venv/bin/python" -m pip install --upgrade pip wheel setuptools
"${APP_DIR}/.venv/bin/pip" install -r "${APP_DIR}/astropy/requirements.txt"
"${APP_DIR}/.venv/bin/pip" install -e "${APP_DIR}/flatlib-ctrad2"

chmod +x "${APP_DIR}/scripts/"*.sh

install -m 0644 "${APP_DIR}/deploy/systemd/horosa-chart.service" /etc/systemd/system/horosa-chart.service
install -m 0644 "${APP_DIR}/deploy/systemd/horosa-api.service" /etc/systemd/system/horosa-api.service
sed -i.bak \
  -e "s/^MemoryHigh=.*/MemoryHigh=${CHART_MEMORY_HIGH}/" \
  -e "s/^MemoryMax=.*/MemoryMax=${CHART_MEMORY_MAX}/" \
  /etc/systemd/system/horosa-chart.service
sed -i.bak \
  -e "s/^MemoryHigh=.*/MemoryHigh=${API_MEMORY_HIGH}/" \
  -e "s/^MemoryMax=.*/MemoryMax=${API_MEMORY_MAX}/" \
  /etc/systemd/system/horosa-api.service

sed "s/server_name _;/server_name ${PUBLIC_HOST};/" "${APP_DIR}/deploy/nginx/horosa-web.conf" \
  > /etc/nginx/sites-available/horosa-web
ln -sf /etc/nginx/sites-available/horosa-web /etc/nginx/sites-enabled/horosa-web
rm -f /etc/nginx/sites-enabled/default
nginx -t

systemctl daemon-reload
systemctl enable --now horosa-chart.service
systemctl restart horosa-chart.service
sleep 3
systemctl enable --now horosa-api.service
systemctl restart horosa-api.service
systemctl restart nginx

echo "Waiting for Horosa services..."
for _ in $(seq 1 90); do
  if curl -fsS --max-time 3 http://127.0.0.1:8899/ >/dev/null &&
     curl -fsS --max-time 5 http://127.0.0.1:80/ >/dev/null &&
     nc -z 127.0.0.1 9999 >/dev/null 2>&1; then
    echo "Horosa full stack is reachable."
    exit 0
  fi
  sleep 2
done

echo "Horosa services did not become healthy in time." >&2
systemctl --no-pager --full status horosa-chart.service || true
systemctl --no-pager --full status horosa-api.service || true
journalctl -u horosa-chart.service -n 120 --no-pager || true
journalctl -u horosa-api.service -n 160 --no-pager || true
exit 1
