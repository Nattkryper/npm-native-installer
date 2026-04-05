#!/usr/bin/env bash
set -e

echo "======================================"
echo " Installing Nginx Proxy Manager (Native)"
echo "======================================"

apt update && apt upgrade -y
apt install -y curl git build-essential python3-pip unzip ca-certificates lsb-release gnupg sqlite3 libsqlite3-dev

# Node.js
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs

# OpenResty
curl -fsSL https://openresty.org/package/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/openresty.gpg
cat <<EOF >/etc/apt/sources.list.d/openresty.list
deb [signed-by=/usr/share/keyrings/openresty.gpg] https://openresty.org/package/debian $(lsb_release -sc) openresty
EOF

apt update
apt install -y openresty
systemctl enable openresty

# Download NPM
cd /opt
LATEST=$(curl -s https://api.github.com/repos/NginxProxyManager/nginx-proxy-manager/releases/latest | grep tarball_url | cut -d '"' -f 4)
curl -L "$LATEST" -o npm.tar.gz

rm -rf nginxproxymanager
mkdir nginxproxymanager
tar -xzf npm.tar.gz --strip-components=1 -C nginxproxymanager
rm npm.tar.gz

# Backend
cd /opt/nginxproxymanager/backend

mkdir -p /var/lib/npm

cat <<EOF >config/production.json
{
  "database": {
    "engine": "knex-native",
    "knex": {
      "client": "better-sqlite3",
      "connection": {
        "filename": "/var/lib/npm/database.sqlite"
      },
      "useNullAsDefault": true
    }
  }
}
EOF

npm install --omit=dev

# Frontend
cd /opt/nginxproxymanager/frontend
npm install
npm run build

mkdir -p /opt/nginxproxymanager/frontend-dist
cp -r dist/* /opt/nginxproxymanager/frontend-dist/
cp -r public/images /opt/nginxproxymanager/frontend-dist/images

# Systemd
cat <<EOF >/etc/systemd/system/npm.service
[Unit]
Description=Nginx Proxy Manager
After=network.target openresty.service
Wants=openresty.service

[Service]
WorkingDirectory=/opt/nginxproxymanager
ExecStart=/usr/bin/node /opt/nginxproxymanager/backend/index.js
Restart=always
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now openresty
systemctl enable --now npm

IP=$(hostname -I | awk '{print $1}')

echo "======================================"
echo "✅ Nginx Proxy Manager Installed!"
echo "➡ http://$IP:81"
echo "➡ Login: admin@example.com / changeme"
echo "======================================"