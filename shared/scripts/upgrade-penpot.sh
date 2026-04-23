#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="/etc/penpot/penpot.env"
COMPOSE_FILE="/opt/penpot/compose/docker-compose.yaml"
TARGET_VERSION="${1:-}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "missing environment file: ${ENV_FILE}" >&2
  exit 1
fi

if [[ -n "${TARGET_VERSION}" ]]; then
  sudo sed -i "s/^PENPOT_VERSION=.*/PENPOT_VERSION=\"${TARGET_VERSION}\"/" "${ENV_FILE}"
fi

sudo bash -lc "
  set -euo pipefail
  set -a
  source '${ENV_FILE}'
  set +a
  cd /opt/penpot/compose
  /usr/bin/docker compose -f '${COMPOSE_FILE}' pull
  /usr/bin/docker compose -f '${COMPOSE_FILE}' up -d
"

echo "Penpot upgrade completed"
echo "version: ${TARGET_VERSION:-unchanged}"
