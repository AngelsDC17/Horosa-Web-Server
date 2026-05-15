# DigitalOcean Droplet Full-Stack Deployment

Use this path when Horosa must run with every feature enabled. The App Platform
Static Site spec only deploys the frontend; the full product also needs the Java
API, Python chart service, MongoDB, Redis, and an `/api` reverse proxy.

## Tested Shape

The delivery-tested shape is DigitalOcean Basic `s-4vcpu-8gb`: 4 vCPU, 8GB RAM,
USD 48/month, about USD 0.07143/hour. It is inexpensive for a short validation
run and gives the Python chart engine enough headroom for first-hit primary
direction model loading without throttling.

已实测的交付规格是 DigitalOcean Basic `s-4vcpu-8gb`：4 核、8GB 内存，
USD 48/月，约 USD 0.07143/小时。短时验收成本很低，同时能给 Python 图表
服务足够余量，避免主限法模型首次加载时被 systemd 内存水位节流。

| Part | Runtime |
|---|---|
| Frontend | Nginx serves `astrostudyui/dist` |
| API | `astrostudyboot.jar` on OpenJDK 17 |
| Chart engine | Python venv running `astropy/websrv/webchartsrv.py` |
| Database | MongoDB 7 container, bound to `127.0.0.1` |
| Cache | Redis 7 container, bound to `127.0.0.1` |
| Reverse proxy | Nginx `/api/` -> `127.0.0.1:9999/` |

`s-1vcpu-2gb` can boot the optimized stack for cheap smoke checks, but it is no
longer the recommended handoff target because primary-direction workloads can
load several model files on first use. Use 4c/8GB for a repo you are giving to
someone else.

`s-1vcpu-2gb` 可以用于便宜的连通性冒烟测试，但不再作为交付推荐规格；
主限法第一次使用时会加载多份模型文件。要交给别人实际使用时，请用 4 核 8GB。

## Bundle-Based Install

Build the frontend and backend locally, then upload these paths to
`/opt/horosa-web` on the Droplet:

```text
astrostudyui/dist
astrostudysrv/astrostudyboot/target/astrostudyboot.jar
astropy
flatlib-ctrad2
scripts
deploy
.env.example
```

Then run:

```bash
sudo bash /opt/horosa-web/deploy/digitalocean-droplet/install_fullstack.sh
```

Recommended 4c/8GB command:

```bash
PUBLIC_HOST=your-domain.com HOROSA_JAVA_XMX=1536m HOROSA_CHART_THREAD_POOL=8 \
  HOROSA_CHART_MEMORY_HIGH=1536M HOROSA_CHART_MEMORY_MAX=2560M \
  HOROSA_API_MEMORY_HIGH=2048M HOROSA_API_MEMORY_MAX=3072M \
  sudo -E bash /opt/horosa-web/deploy/digitalocean-droplet/install_fullstack.sh
```

Optional overrides:

| Variable | Default | Purpose |
|---|---:|---|
| `HOROSA_JAVA_XMX` | `1536m` | Java API heap cap |
| `HOROSA_CHART_THREAD_POOL` | `8` | CherryPy chart-service worker pool |
| `HOROSA_CHART_MEMORY_HIGH` | `1536M` | systemd soft memory throttle point for Python |
| `HOROSA_CHART_MEMORY_MAX` | `2560M` | systemd hard memory cap for Python |
| `HOROSA_API_MEMORY_HIGH` | `2048M` | systemd soft memory throttle point for Java |
| `HOROSA_API_MEMORY_MAX` | `3072M` | systemd hard memory cap for Java |
| `HOROSA_ENABLE_PD_WARMUP` | `0` | Optional primary-direction warmup before chart service accepts traffic |

For a tiny 2GB smoke-test Droplet, override `HOROSA_CHART_THREAD_POOL=4`,
`HOROSA_JAVA_XMX=768m`, `HOROSA_CHART_MEMORY_HIGH=1024M`, and
`HOROSA_CHART_MEMORY_MAX=1536M`.

如果只是 2GB 小机器冒烟测试，请覆盖 `HOROSA_CHART_THREAD_POOL=4`、
`HOROSA_JAVA_XMX=768m`、`HOROSA_CHART_MEMORY_HIGH=1024M` 和
`HOROSA_CHART_MEMORY_MAX=1536M`。

## 2026-05-15 Validation Snapshot

On `s-4vcpu-8gb`, a full Linux deployment passed the runtime API benchmark and
browser smoke test:

| Check | Result |
|---|---|
| API benchmark threshold | 12 seconds, all scenarios passed |
| Slowest API scenario | `/chart` shared chart render, 6.43s cold / 1.12s warm |
| Primary direction | `/predict/pd`, 0.29s first measured request / 0.23s repeat after deployment smoke |
| Browser module smoke | 17 top-level modules selected successfully |
| 三式合一 | `起盘` completed and produced computed overview fields |
| Browser console errors | 0 |
| Post-test memory | about 1.5GB used, about 6.0GB available |

## Verification

From the Droplet:

```bash
curl -fsS http://127.0.0.1/
curl -fsS http://127.0.0.1:8899/
systemctl status horosa-chart.service horosa-api.service nginx
docker ps --filter name=horosa-mongo --filter name=horosa-redis
```

From a browser, open `http://DROPLET_IP/` and verify the main modules render:

```text
星盘, 三维盘, 推运盘, 量化盘, 关系盘, 节气盘, 星体地图, 七政四余,
希腊星术, 印度律盘, 八字紫微, 易与三式, 万年历, 风水, 三式合一, AI分析
```

The browser should not show `排盘失败`, the React `#root` should not be empty,
and `/api/*` requests should return `200` during normal chart flows.
