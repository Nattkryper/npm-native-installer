#!/usr/bin/env bash
set -e

echo "========================================="
echo " Updating Nginx Proxy Manager"
echo "========================================="

systemctl stop npm

cd /opt
rm -rf nginxproxymanager

LATEST=$(curl -s https://api.github.com/repos/NginxProxyManager/nginx-proxy-manager/releases/latest | grep tarball_url | cut -d '"' -f 4)
curl -L "$LATEST" -o npm.tar.gz
mkdir nginxproxymanager
tar -xzf npm.tar.gz --strip-components=1 -C nginxproxymanager
rm npm.tar.gz

cd /opt/nginxproxymanager/backend
npm install --omit=dev

cd /opt/nginxproxymanager/frontend
npm install
npm run build

systemctl start npm

echo "✅ Update complete!"