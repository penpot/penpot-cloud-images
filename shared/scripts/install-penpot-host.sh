#!/usr/bin/env bash
set -euo pipefail

sudo mkdir -p /opt/penpot/bin
sudo mkdir -p /opt/penpot/config
sudo mkdir -p /opt/penpot/compose
sudo mkdir -p /etc/penpot
sudo mkdir -p /etc/nginx/conf.d

sudo cp /tmp/penpot-docker-compose.yaml /opt/penpot/compose/docker-compose.yaml
sudo cp /tmp/penpot.env.example /opt/penpot/config/penpot.env.example
sudo cp /tmp/penpot-nginx.conf /etc/nginx/conf.d/penpot.conf
sudo cp /tmp/configure-penpot.sh /opt/penpot/bin/configure-penpot.sh
sudo cp /tmp/upgrade-penpot.sh /opt/penpot/bin/upgrade-penpot.sh
sudo cp /tmp/penpot-compose.service /etc/systemd/system/penpot-compose.service

sudo chmod 0755 /opt/penpot/bin/configure-penpot.sh
sudo chmod 0755 /opt/penpot/bin/upgrade-penpot.sh
sudo touch /etc/penpot/penpot.env
sudo chmod 0600 /etc/penpot/penpot.env

sudo rm -f /etc/nginx/conf.d/default.conf
sudo nginx -t
sudo systemctl daemon-reload
if systemctl list-unit-files amazon-ssm-agent.service >/dev/null 2>&1; then
  sudo systemctl enable amazon-ssm-agent
  sudo systemctl restart amazon-ssm-agent
fi
