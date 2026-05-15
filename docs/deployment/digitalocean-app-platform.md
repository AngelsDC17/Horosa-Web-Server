# DigitalOcean App Platform Deployment

This repo includes a DigitalOcean App Platform static-site spec for the Horosa web frontend. It is intentionally frontend-only: the Java API, Python chart service, MongoDB, and Redis should still run on a Droplet or another backend host unless you later split them into dedicated App Platform services.

## One-Click Deploy

[![Deploy to DO](https://www.deploytodo.com/do-btn-blue.svg)](https://cloud.digitalocean.com/apps/new?repo=https://github.com/Horace-Maxwell/Horosa-Web-Server/tree/main)

DigitalOcean's Deploy button expects `.do/deploy.template.yaml`, with the app spec nested under `spec:`. The repo also keeps `.do/app.yaml` for `doctl apps create --spec .do/app.yaml` or manual App Platform import.

## App Platform Settings

Use these values if you create the app manually:

| Setting | Value |
|---|---|
| Component type | Static Site |
| Source directory | `astrostudyui` |
| Build command | `npm ci --ignore-scripts --no-audit --no-fund && node scripts/patch_quill_domnodeinserted.js && npm run build:digitalocean` |
| Output directory | `dist` |
| Index document | `index.html` |
| Catchall document | `index.html` |
| Build env `HOROSA_LOW_MEMORY_BUILD` | `1` |
| Build env `HOROSA_PUBLIC_SERVER_ROOT` | `/api` or your external API URL |
| Build env `HOROSA_PUBLIC_PATH` | `/` |
| Build env `NODE_OPTIONS` | `--openssl-legacy-provider --max-old-space-size=640` |

`catchall_document: index.html` is required because Horosa is a single-page React/Umi app. Without it, direct deep links can 404 on App Platform.

The frontend package pins the App Platform buildpack to Node.js 20 and npm 10 through `astrostudyui/package.json` `engines`. This avoids surprising builder drift to a newer Node/npm pair while preserving the same command shown above.

## Why This Fixes the Build OOM

The old frontend was one large entry graph: `src/pages/index.js` imported the astrology workspace, 3D charting, multimedia, AI export, user drawers, admin tools, and every traditional-discipline module at startup. On memory-constrained builders this can push webpack/V8 into the `Ineffective mark-compacts near heap limit` failure.

The App Platform build path now changes the shape of the frontend without removing features:

| Optimization | Effect |
|---|---|
| `React.lazy` for top-level workspaces | Heavy modules are compiled into async chunks instead of one giant entry bundle. |
| Low-memory webpack cache groups | React, Ant Design, 3D, media, and export dependencies are isolated into stable vendor chunks. |
| `build:digitalocean` script | App Platform gets the same build command every time, with the required OpenSSL and heap flags. |
| `/api` production default | Static frontend can call the backend through an App Platform route, Nginx route, or external API gateway. |
| `/` frontend public path | App Platform can serve hashed JS/CSS directly from the static-site root. |

This is not a feature downgrade. The same components remain in the build; they are just loaded when the user opens that workspace.

## Current Local Verification

Run this after changing frontend code:

```bash
cd astrostudyui
rm -rf dist
/usr/bin/time -l env NODE_OPTIONS="--openssl-legacy-provider --max-old-space-size=640" npm run build:digitalocean
```

Then inspect generated chunks:

```bash
find dist -maxdepth 2 -name '*.js' -print0 | xargs -0 ls -lh | sort -k5 -h
du -sh dist
```

Expected result: the build succeeds under a constrained heap and produces multiple async JavaScript chunks instead of a single huge `umi.*.js`.

For the full local preflight, use:

```bash
./scripts/verify_digitalocean_frontend.sh
```

That script runs the App Platform-compatible build, verifies that `index.html` references real assets, starts a static server, and checks that the entry JS/CSS plus at least one async vendor chunk return `200 OK`.

The latest local verification result is:

| Check | Result |
|---|---:|
| 512MB V8 heap | Fails, but peak RSS drops to about 766 MiB instead of the old 1.75 GiB class build. |
| 544MB V8 heap | Passes when `node_modules` is warm, but not stable after a fresh `npm ci`. |
| 640MB V8 heap | Passes after a fresh `npm ci`. |
| Full App Platform-style command | `npm ci --ignore-scripts --no-audit --no-fund && node scripts/patch_quill_domnodeinserted.js && npm run build:digitalocean` passes. |
| Full command peak RSS | about 995 MiB, including dependency install. |
| 640MB build time | about 19-22s for webpack build; about 35s including fresh `npm ci` on the local Mac. |
| Linux App Platform simulation | Passes from a fresh GitHub clone in `node:20-bookworm` with a 2GB container memory limit. |
| Largest JS after split | `umi.*.js`, 2.5 MB / 605 KB gzip |
| Previous largest JS before split | `umi.*.js`, 7.6 MB / about 2.0 MB gzip |

The default DigitalOcean build heap is therefore intentionally set to 640MB: it is safely above the previously failing App Platform heap range, while still preventing Node from claiming an unnecessarily large heap inside a small build container.

GitHub Actions also runs this preflight on Ubuntu through `.github/workflows/digitalocean-frontend-preflight.yml`, so future pushes should fail early if the static-site build regresses.

## Backend Deployment Shape

For the full Horosa web stack, keep the backend on a VM first:

```text
DigitalOcean App Platform static frontend
  -> /api or external API URL
  -> Java Spring API
  -> Python chart service
  -> MongoDB / Redis
```

If you later migrate the backend to App Platform services, split them into separate components and keep the Python chart service private. Do not expose the chart service directly to the public internet.

## No-Downgrade Checklist

- 星盘, 三维盘, 推运盘, 量化盘, 关系盘, 节气盘, 星体地图, 七政四余, 希腊星术, 印度律盘, 八字紫微, 易与三式, 万年历, 西洋游戏, 风水, 三式合一, AI 分析 are still imported and built.
- User drawers, chart list, case list, selectors, annotations, tools, homepage setup, reader, live player, admin tools, and deep-learning setup remain present.
- The frontend still builds to `astrostudyui/dist`.
- API root remains configurable through `HOROSA_PUBLIC_SERVER_ROOT`.
