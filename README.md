<div align="center">

# Horosa Web Server / 星阙网页端服务器版

### Server-optimized Horosa web deployment
### 面向服务器部署优化的星阙网页端版本

[![Repository](https://img.shields.io/badge/GitHub-Repository-3f3f46?logo=github&logoColor=white)](https://github.com/Horace-Maxwell/Horosa-Web-Server)
[![Platform](https://img.shields.io/badge/platform-Linux%20server%20%7C%20Nginx%20%7C%20Java%20%7C%20Python-black)](https://github.com/Horace-Maxwell/Horosa-Web-Server)
[![Frontend](https://img.shields.io/badge/frontend-React%20%2F%20Umi-2563eb)](astrostudyui/)
[![Backend](https://img.shields.io/badge/backend-Spring%20Boot%20%2B%20CherryPy-0f766e)](astrostudysrv/)
[![Deployment](https://img.shields.io/badge/deployment-systemd%20%2B%20Nginx-2ea043)](deploy/)
[![Memory](https://img.shields.io/badge/default%20JVM%20heap-1024MiB-d97706)](scripts/measure_server_footprint.sh)
[![Chart Workers](https://img.shields.io/badge/chart%20workers-default%208-a855f7)](astropy/websrv/webchartsrv.py)

[![Deploy to DO](https://www.deploytodo.com/do-btn-blue.svg)](https://cloud.digitalocean.com/apps/new?repo=https://github.com/Horace-Maxwell/Horosa-Web-Server/tree/main)

<p><strong>English:</strong> This repository isolates the Horosa web stack into a server-first project, so deployment, resource limits, reverse proxying, and production health checks can evolve without disturbing the signed desktop app.</p>
<p><strong>中文：</strong>这个仓库把星阙网页端单独拆成服务器优先的项目，让部署、资源限制、反向代理和生产健康检查可以独立优化，不影响已经稳定的桌面 App。</p>

</div>

## Start Here / 先看这里

| English | 中文 |
|---|---|
| Use this repository when you want to run Horosa as a web service on a VPS or cloud server. | 如果你要把星阙作为网页服务部署到 VPS 或云服务器，请使用这个仓库。 |
| The desktop app release pipeline is intentionally not part of this project. | 桌面 App 的打包、签名、公证流程刻意不放进这个项目。 |
| Production routing is designed as `Nginx -> /api -> Java API -> Python chart service`. | 生产路由设计为 `Nginx -> /api -> Java API -> Python 图表服务`。 |
| DigitalOcean App Platform can deploy the frontend with the included one-click static-site spec. | DigitalOcean App Platform 可以使用仓库内置的一键部署配置发布前端静态站点。 |

## What Is Included / 包含内容

| Path | English | 中文 |
|---|---|---|
| `astrostudyui/` | React/Umi frontend source. Build it once, serve `dist/` statically. | React/Umi 前端源码。生产环境只构建一次，用 Nginx 静态托管 `dist/`。 |
| `astrostudysrv/` | Java Spring backend services and the final boot jar. | Java Spring 后端服务与最终启动 jar。 |
| `astropy/` | Python astrology and chart-calculation service. | Python 占星与盘面计算服务。 |
| `flatlib-ctrad2/` | Bundled calculation dependency used by `astropy`. | `astropy` 使用的内置计算依赖。 |
| `scripts/` | Build, start, stop, health-check, and footprint measurement scripts. | 构建、启动、停止、健康检查与内存足迹测量脚本。 |
| `deploy/` | Nginx, systemd, MongoDB, and Redis production templates. | Nginx、systemd、MongoDB、Redis 的生产模板。 |
| `.do/` | DigitalOcean App Platform one-click deploy and app-spec templates. | DigitalOcean App Platform 一键部署与 app-spec 模板。 |

The copy intentionally excludes local caches, `node_modules`, Java `target` folders, frontend `dist`, desktop runtime bundles, logs, and local `.env` files.

本仓库刻意排除了本地缓存、`node_modules`、Java `target`、前端 `dist`、桌面 runtime、日志和本机 `.env`。

## Server Sizing / 服务器配置建议

| Scenario / 场景 | CPU | RAM | Disk |
|---|---:|---:|---:|
| Private testing / 私人测试 | 2 vCPU | 4GB | 80GB SSD |
| Public small launch / 小规模公开使用 | 4 vCPU | 8GB | 120-160GB SSD |
| Heavier concurrent usage / 更高并发 | 8 vCPU | 16GB | 200GB+ SSD |

Most memory pressure comes from MongoDB cache, Java heap, and Python chart-service concurrency. Do not run `umi dev` in production.

最吃内存的是 MongoDB 缓存、Java 堆和 Python 图表服务并发。生产环境不要跑 `umi dev`。

## Verified Footprint / 已验证资源数据

Measured locally after production frontend build and backend jar build:

本地在完成前端生产构建和后端 jar 构建后测得：

| Metric / 指标 | Result / 结果 |
|---|---:|
| Git-tracked source / Git 追踪源码体积 | 761.9 MiB, 1,815 files |
| Frontend production dist / 前端生产产物 | 9.3 MB |
| Backend boot jar / 后端启动 jar | 309 MB |
| Previous frontend build peak RSS / 原前端构建峰值 RSS | about 1.75 GB |
| Optimized App Platform build / 优化后 App Platform 构建 | passes after fresh `npm ci` at 640MB V8 heap, about 995 MiB peak RSS |
| Largest frontend JS / 最大前端 JS | reduced from 7.6 MB to 2.5 MB |
| Backend build peak RSS / 后端构建峰值 RSS | about 494 MB |
| JVM default MaxHeapSize on this Mac / 本机 Java 默认最大堆 | 4096 MiB |
| Tuned JVM MaxHeapSize / 优化后 Java 最大堆 | 1024 MiB |
| Chart service RSS with 8 workers / 8 线程图表服务 RSS | about 37.5 MB cold check |
| Live API RSS after startup / API 启动后 RSS | about 348 MB |
| Live chart RSS after startup / 图表服务启动后 RSS | about 22 MB |

Run the same check on a server:

在服务器上复测：

```bash
./scripts/measure_server_footprint.sh
```

## Production Layout / 生产目录

Recommended path:

推荐路径：

```bash
/opt/horosa-web
```

Create the server env file:

创建服务器环境文件：

```bash
cp .env.example .env
```

Typical production values:

常见生产配置：

```bash
HOROSA_DOMAIN=your-domain.com
HOROSA_PUBLIC_SERVER_ROOT=/api
HOROSA_JAVA_XMX=1024m
HOROSA_CHART_THREAD_POOL=8
```

## Build / 构建

Install system dependencies first:

先安装系统依赖：

```bash
sudo apt update
sudo apt install -y openjdk-17-jdk maven python3 python3-venv python3-pip nodejs npm nginx redis-server mongodb-org
```

Prepare Python:

准备 Python 环境：

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r astropy/requirements.txt
pip install -e flatlib-ctrad2
```

Build backend and frontend:

构建后端与前端：

```bash
./scripts/build_backend.sh
./scripts/build_frontend.sh
```

## DigitalOcean App Platform / DigitalOcean 一键部署

The frontend can be deployed as a DigitalOcean App Platform Static Site using the included `.do/deploy.template.yaml`. The build uses lazy-loaded workspaces and webpack vendor chunking so the full Horosa feature set remains intact while avoiding the previous single-entry build memory spike.

前端可以用仓库内置的 `.do/deploy.template.yaml` 作为 DigitalOcean App Platform Static Site 一键部署。构建过程已经改成工作区按需加载和 webpack vendor 分包，星阙完整功能不删减，同时避开以前单一入口包导致的构建内存尖峰。

```bash
cd astrostudyui
npm ci --ignore-scripts --no-audit --no-fund
node scripts/patch_quill_domnodeinserted.js
npm run build:digitalocean
```

Full guide:

完整说明：

[`docs/deployment/digitalocean-app-platform.md`](docs/deployment/digitalocean-app-platform.md)

Before handing the repo to another machine or deploying on DigitalOcean, run the same frontend deployment verification locally:

在把仓库交给别人或部署到 DigitalOcean 前，可以先跑同一套前端部署验收：

```bash
./scripts/verify_digitalocean_frontend.sh
```

## Run / 运行

Start services:

启动服务：

```bash
./scripts/start_all.sh
```

Check health:

检查健康状态：

```bash
./scripts/healthcheck.sh
```

Stop services:

停止服务：

```bash
./scripts/stop_all.sh
```

## Production Routing / 生产路由

Use [`deploy/nginx/horosa-web.conf`](deploy/nginx/horosa-web.conf) as the starting point.

请以 [`deploy/nginx/horosa-web.conf`](deploy/nginx/horosa-web.conf) 为起点。

| Route / 路由 | Target / 目标 |
|---|---|
| `/` | `astrostudyui/dist` static frontend / 静态前端 |
| `/api/` | Java Spring backend on `127.0.0.1:9999` / Java 后端 |
| Python chart service / Python 图表服务 | Private `127.0.0.1:8899`, called by Java / 仅内网，由 Java 调用 |

## Memory Tuning / 内存调优

For a 4GB server:

4GB 服务器：

```bash
HOROSA_JAVA_XMX=768m
HOROSA_CHART_THREAD_POOL=4
```

For an 8GB server:

8GB 服务器：

```bash
HOROSA_JAVA_XMX=1536m
HOROSA_CHART_THREAD_POOL=8
```

The systemd templates enable `MemoryAccounting`, `MemoryHigh`, and `MemoryMax`. By default, Java is capped at 2GB by systemd and 1GB by JVM heap; the Python chart service is capped at 768MB and defaults to 8 CherryPy workers instead of the historical fixed 30-worker pool.

systemd 模板已经启用 `MemoryAccounting`、`MemoryHigh` 和 `MemoryMax`。默认情况下，Java 被 systemd 限制在 2GB、JVM 堆限制在 1GB；Python 图表服务限制在 768MB，并从历史固定 30 线程改成默认 8 个 CherryPy worker。

## Maintainer Notes / 维护说明

| English | 中文 |
|---|---|
| Keep feature parity with the app web code, but put server-only deployment optimization here first. | 保持与 App 内网页端功能一致，但服务器专用优化优先放在这里验证。 |
| Do not commit `.env`, local data, caches, `node_modules`, build outputs, runtime bundles, logs, or local test pids. | 不要提交 `.env`、本地数据、缓存、`node_modules`、构建产物、runtime、日志或本地测试 pid。 |
| If model files grow beyond GitHub limits, move them to Git LFS or release assets before the repository becomes hard to clone. | 如果模型文件继续变大，应该在仓库变得难以克隆前迁移到 Git LFS 或 release assets。 |

## Acknowledgements / 致谢

本项目为参考星阙 Horosa-荀爽（Herakleios）所发布的星阙 App 和 Web，并在网页端服务器部署、运行时打包、功能整合与使用体验上继续整理制作。源流不可忘：星阙 Horosa 最早由郑大哥一手创建，荀爽（Herakleios）曾参与辅助设计，并将相关 App 与 Web 版本公开出来供后来者研究、学习与延展。

Please do not forget the contributions of 爽哥 and 郑大哥. This server edition continues from their groundwork with respect, gratitude, and the hope that Horosa can remain useful to more people over time.
