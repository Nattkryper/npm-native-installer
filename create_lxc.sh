#!/usr/bin/env bash
set -e

echo "=== Nginx Proxy Manager LXC Creator ==="

# ---------------------------------------------------
# 1) AUTO-DETECT STORAGE THAT SUPPORTS ROOTDIR
# ---------------------------------------------------
echo "Detecting Proxmox storage for LXC..."

STORAGE="local"

if [ -z "$STORAGE" ]; then
    echo "ERROR: No storage pool found that supports 'rootdir'!"
    echo "Enable 'Container' content in Datacenter → Storage."
    exit 1
fi

echo "✅ Storage detected: $STORAGE"

# ---------------------------------------------------
# 2) SETTINGS
# ---------------------------------------------------
HOSTNAME="nginxproxymanager"
MEMORY="2048"
CORES="2"
DISK="16"
UNPRIV="1"
TEMPLATE="local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
REPO="https://raw.githubusercontent.com/Nattkryper/npm-native-installer/main"

echo "Hostname: $HOSTNAME"
echo "CPU: $CORES"
echo "RAM: $MEMORY MB"
echo "Disk: ${DISK}GB"
echo "Unprivileged: Yes"
echo "---------------------------------------"

# ---------------------------------------------------
# 3) GET NEXT FREE CTID
# ---------------------------------------------------
CTID=$(pvesh get /cluster/nextid)
echo "Using next available CTID: $CTID"

# ---------------------------------------------------
# 4) ENSURE DEBIAN TEMPLATE EXISTS
# ---------------------------------------------------
if ! pct templates | grep -q "debian-12-standard"; then
    echo "Downloading Debian 12 template..."
    pveam update >/dev/null
    pveam download local debian-12-standard_12.2-1_amd64.tar.zst
fi

# ---------------------------------------------------
# 5) CREATE THE LXC
# ---------------------------------------------------
echo "Creating container..."
pct create $CTID $TEMPLATE \
    --hostname $HOSTNAME \
    --cores $CORES \
    --memory $MEMORY \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp \
    --unprivileged $UNPRIV \
    --storage $STORAGE \
    --rootfs $STORAGE:${DISK} \
    --features nesting=1 \
    --ostype debian \
    --timezone host

pct start $CTID
sleep 5

# ---------------------------------------------------
# 6) INJECT AND RUN INSTALLER
# ---------------------------------------------------
pct exec $CTID -- sh -c "apt update && apt install -y curl"
pct exec $CTID -- sh -c "curl -fsSL $REPO/install.sh -o /root/install.sh && chmod +x /root/install.sh"

echo "Running installer inside LXC..."
pct exec $CTID -- bash /root/install.sh

# ---------------------------------------------------
# 7) PRINT FINAL INFO
# ---------------------------------------------------
IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')

echo "========================================="
echo "✅ LXC created and NPM installed!"
echo "➡ Container ID: $CTID"
echo "➡ Access URL: http://$IP:81"
echo "➡ Login: admin@example.com / changeme"
echo "========================================="