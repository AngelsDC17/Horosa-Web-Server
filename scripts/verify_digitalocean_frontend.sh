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

python3 - <<'PY'
import pathlib
import re
import sys

dist = pathlib.Path("astrostudyui/dist")
html = (dist / "index.html").read_text(encoding="utf-8")
entry_match = re.search(r'<script\s+src=["\']\/([^"\']*umi\.[^"\']+\.js)["\']></script>', html)
if not entry_match:
    print("index.html does not reference the Umi entry script", file=sys.stderr)
    sys.exit(1)

entry_name = entry_match.group(1)
entry_source = (dist / entry_name).read_text(encoding="utf-8")
bootstrap = re.search(r"\.push\(\[([^\]]+)\]\),a\(\)", entry_source)
if not bootstrap:
    print("entry script does not expose an initial chunk dependency list")
    sys.exit(1)

numbers = [int(part.strip()) for part in bootstrap.group(1).split(",") if part.strip().isdigit()]
required_ids = []
for chunk_id in numbers[1:]:
    if chunk_id not in required_ids:
        required_ids.append(chunk_id)

chunk_files = {}
for js_file in dist.glob("*.js"):
    if js_file.name == entry_name:
        continue
    source = js_file.read_text(encoding="utf-8")
    match = re.search(r"\.push\(\[\[([^\]]+)\]", source)
    if not match:
        continue
    for part in match.group(1).split(","):
        part = part.strip()
        if part.isdigit():
            chunk_files[int(part)] = js_file.name

missing = [chunk_id for chunk_id in required_ids if chunk_id not in chunk_files]
if missing:
    print(f"missing initial chunk file(s) for id(s): {missing}", file=sys.stderr)
    sys.exit(1)

not_in_html = [
    chunk_files[chunk_id]
    for chunk_id in required_ids
    if f'src="/{chunk_files[chunk_id]}"' not in html
]
if not_in_html:
    print(
        "index.html does not include required initial chunk script(s): "
        + ", ".join(not_in_html),
        file=sys.stderr,
    )
    sys.exit(1)

print(f"verified {len(required_ids)} initial webpack chunk scripts are included in index.html")
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
