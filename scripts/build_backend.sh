#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRV="${ROOT}/astrostudysrv"

modules=(
  boundless
  basecomm
  astroswisseph
  medialib
  media
  iot
  image
  astrostudy
  astrostudycn
  astrodeeplearn
  astroreader
  astroesp
  astrostudyboot
)

for module in "${modules[@]}"; do
  if [ -f "${SRV}/${module}/pom.xml" ]; then
    echo "==> Building ${module}"
    if [ "${module}" = "astrostudyboot" ]; then
      (cd "${SRV}/${module}" && mvn -DskipTests package)
    else
      (cd "${SRV}/${module}" && mvn -DskipTests install)
    fi
  fi
done

echo "Backend jar: ${SRV}/astrostudyboot/target/astrostudyboot.jar"
