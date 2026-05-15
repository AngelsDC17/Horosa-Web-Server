# Horosa Web Server

This repository is the server-focused web edition of Horosa. It is separated from the macOS app packaging flow so the web deployment can be optimized for Linux servers without disturbing the desktop app.

## What Is Included

- `astrostudyui/`: React/Umi web frontend source.
- `astrostudysrv/`: Java Spring backend services.
- `astropy/`: Python astrology/chart calculation service.
- `flatlib-ctrad2/`: bundled astrology calculation dependency used by `astropy`.
- `scripts/`: production-oriented build, start, stop, and health-check scripts.
- `deploy/`: Nginx, systemd, MongoDB, and Redis deployment templates.

The copy intentionally excludes local caches, `node_modules`, Java `target` folders, frontend `dist`, and desktop runtime artifacts.

## Recommended Server

Minimum practical production server:

| Scenario | CPU | RAM | Disk |
|---|---:|---:|---:|
| Private testing | 2 vCPU | 4GB | 80GB SSD |
| Public small launch | 4 vCPU | 8GB | 120-160GB SSD |
| Heavier concurrent usage | 8 vCPU | 16GB | 200GB+ SSD |

The most memory-sensitive parts are MongoDB cache, Java heap, and Python chart-service concurrency. Do not run the frontend through `umi dev` or Vite in production.

## Production Layout

Recommended server path:

```bash
/opt/horosa-web
```

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Then edit:

```bash
HOROSA_DOMAIN=your-domain.com
HOROSA_PUBLIC_SERVER_ROOT=/api
HOROSA_JAVA_XMX=1024m
HOROSA_CHART_THREAD_POOL=8
```

## Build

Install system dependencies first:

```bash
sudo apt update
sudo apt install -y openjdk-17-jdk maven python3 python3-venv python3-pip nodejs npm nginx redis-server mongodb-org
```

Build Python environment:

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r astropy/requirements.txt
pip install -e flatlib-ctrad2
```

Build backend and frontend:

```bash
./scripts/build_backend.sh
./scripts/build_frontend.sh
```

## Run Locally On The Server

Start all services in the foreground:

```bash
./scripts/start_all.sh
```

Or run individual services:

```bash
./scripts/start_chart_service.sh
./scripts/start_api_service.sh
```

Health check:

```bash
./scripts/healthcheck.sh
```

Measure the local deployment footprint:

```bash
./scripts/measure_server_footprint.sh
```

## Nginx

Use `deploy/nginx/horosa-web.conf` as a starting point. The intended public routing is:

- `/` serves `astrostudyui/dist`
- `/api/` proxies to Java Spring backend
- Python chart service stays private on `127.0.0.1`; Java calls it through `--astrosrv`

## Memory Tuning

For a 4GB server:

```bash
HOROSA_JAVA_XMX=768m
HOROSA_CHART_THREAD_POOL=4
```

For an 8GB server:

```bash
HOROSA_JAVA_XMX=1536m
HOROSA_CHART_THREAD_POOL=8
```

For MongoDB, use the included `deploy/mongodb/mongod.conf` and set:

```yaml
wiredTigerCacheSizeGB: 0.5
```

For Redis, use `deploy/redis/redis.conf` and keep `maxmemory` bounded.

The server edition also ships systemd unit templates with `MemoryAccounting`,
`MemoryHigh`, and `MemoryMax` enabled. The defaults are intentionally
conservative: Java API is capped at 2GB by systemd and 1GB by JVM heap unless
`.env` raises it; the Python chart service is capped at 768MB and defaults to 8
CherryPy worker threads instead of the historical fixed 30-thread pool.

## Notes

- The web server edition should keep feature parity with the app web code.
- Deployment optimizations should be made here first, then backported only when they are also useful for desktop.
- Do not commit `.env`, local data folders, caches, `node_modules`, build outputs, or runtime bundles.
