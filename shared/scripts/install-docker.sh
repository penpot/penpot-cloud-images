#!/usr/bin/env bash
set -euo pipefail

COMPOSE_VERSION="2.39.1"

sudo dnf update -y
sudo dnf install -y docker
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -fsSL "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64" -o /tmp/docker-compose
sudo install -m 0755 /tmp/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose
sudo rm -f /tmp/docker-compose
sudo dnf install -y nginx

sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl enable nginx

docker compose version
sudo usermod -aG docker ec2-user
