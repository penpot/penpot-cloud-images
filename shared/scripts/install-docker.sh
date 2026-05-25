#!/usr/bin/env bash
set -euo pipefail

COMPOSE_VERSION="2.39.1"
COMPOSE_BIN="docker-compose-linux-x86_64"
COMPOSE_DOWNLOAD_URL="https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/${COMPOSE_BIN}"
COMPOSE_CHECKSUM_URL="https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/checksums.txt"

sudo dnf update -y
sudo dnf install -y docker
sudo mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL "${COMPOSE_DOWNLOAD_URL}" -o /tmp/docker-compose
curl -fsSL "${COMPOSE_CHECKSUM_URL}" -o /tmp/docker-compose-checksums.txt
expected_checksum="$(awk '/docker-compose-linux-x86_64$/ {print $1}' /tmp/docker-compose-checksums.txt)"

if [[ -z "${expected_checksum}" ]]; then
  echo "unable to resolve docker compose checksum for ${COMPOSE_BIN}" >&2
  exit 1
fi

echo "${expected_checksum}  /tmp/docker-compose" | sha256sum -c -

sudo install -m 0755 /tmp/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose
rm -f /tmp/docker-compose /tmp/docker-compose-checksums.txt
sudo dnf install -y nginx

sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl enable nginx

docker compose version
sudo usermod -aG docker ec2-user
