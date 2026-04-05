#!/usr/bin/env bash
set -e

echo "======================================"
echo " Uninstalling Nginx Proxy Manager"
echo "======================================"

systemctl stop npm || true
systemctl disable npm || true
rm -f /etc/systemd/system/npm.service
systemctl daemon-reload

systemctl stop openresty || true
systemctl disable openresty || true

apt remove -y openresty nodejs
rm -rf /opt/nginxproxymanager
rm -rf /var/lib/npm

rm -f /etc/apt/sources.list.d/openresty.list
rm -f /usr/share/keyrings/openresty.gpg

echo "✅ NPM Uninstalled"