#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${HOROSA_VERIFY_PORT:-4173}"
DIST="${ROOT}/astrostudyui/dist"

cd "${ROOT}"

./scripts/build_frontend.sh

python3 - <<'PY'
import pathlib
import re
import sys

dist = pathlib.Path("astrostudyui/dist")
index = dist / "index.html"
if not index.exists():
    print("missing dist/index.html", file=sys.stderr)
    sys.exit(1)

html = index.read_text(encoding="utf-8")
refs = re.findall(r"""(?:src|href)=["'](/[^"']+)["']""", html)
missing = []
for ref in refs:
    if ref.startswith("/api/") or ref.startswith("data:"):
        continue
    path = dist / ref.lstrip("/")
    if not path.exists():
        missing.append(ref)

if missing:
    print("missing referenced dist assets:", ", ".join(missing), file=sys.stderr)
    sys.exit(1)

js_files = list(dist.glob("*.js")) + list((dist / "static").glob("*.js"))
if not js_files:
    print("no JavaScript assets generated", file=sys.stderr)
    sys.exit(1)

print(f"verified {len(refs)} HTML asset references and {len(js_files)} JS assets")
PY

python3 -m http.server "${PORT}" --directory "${DIST}" >/tmp/horosa-digitalocean-frontend-http.log 2>&1 &
SERVER_PID="$!"
trap 'kill "${SERVER_PID}" >/dev/null 2>&1 || true' EXIT

for _ in $(seq 1 20); do
  if curl -sfI "http://127.0.0.1:${PORT}/" >/dev/null; then
    break
  fi
  sleep 0.25
done

curl -sfI "http://127.0.0.1:${PORT}/" >/dev/null

ENTRY_FILE="/tmp/horosa-digitalocean-entry-assets.txt"
python3 - <<'PY' > "${ENTRY_FILE}"
import pathlib
import re

html = pathlib.Path("astrostudyui/dist/index.html").read_text(encoding="utf-8")
js = re.search(r"src=[\"'](/[^\"']+\.js)[\"']", html)
css = re.search(r"href=[\"'](/[^\"']+\.css)[\"']", html)
print(js.group(1) if js else "")
print(css.group(1) if css else "")
PY

ENTRY_JS="$(sed -n '1p' "${ENTRY_FILE}")"
ENTRY_CSS="$(sed -n '2p' "${ENTRY_FILE}")"

if [[ -z "${ENTRY_JS}" || -z "${ENTRY_CSS}" ]]; then
  echo "index.html does not reference entry JS/CSS" >&2
  exit 1
fi

curl -sfI "http://127.0.0.1:${PORT}${ENTRY_JS}" >/dev/null
curl -sfI "http://127.0.0.1:${PORT}${ENTRY_CSS}" >/dev/null

VENDOR_JS="$(find "${DIST}" -maxdepth 1 -type f -name 'vendor-*.async.js' | head -1)"
if [[ -n "${VENDOR_JS}" ]]; then
  curl -sfI "http://127.0.0.1:${PORT}/$(basename "${VENDOR_JS}")" >/dev/null
fi

du -sh "${DIST}"
find "${DIST}" -maxdepth 1 -type f -name '*.js' -exec ls -lh {} \; | sort -k5 -h | tail -8

echo "DigitalOcean frontend verification passed on http://127.0.0.1:${PORT}/"
