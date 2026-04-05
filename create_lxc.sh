#!/usr/bin/env bash
set -e

echo "=== Nginx Proxy Manager LXC Creator (PVE 9.1 Compatible) ==="

# ---------------------------------------------------
# STORAGE (your confirmed storage)
# ---------------------------------------------------
STORAGE="local"
echo "✅ Using storage: $STORAGE"

# ---------------------------------------------------
# SETTINGS
# ---------------------------------------------------
HOSTNAME="nginxproxymanager"
MEMORY="2048"
CORES="2"
DISK="16"         # Proxmox 9 uses raw number (no G)
UNPRIV="1"
REPO="https://raw.githubusercontent.com/Nattkryper/npm-native-installer/main"

echo "Hostname: $HOSTNAME"
echo "CPU: $CORES"
echo "RAM: $MEMORY MB"
echo "Disk: ${DISK}GB"
echo "Unprivileged: Yes"
echo "---------------------------------------"

# ---------------------------------------------------
# NEXT FREE CTID
# ---------------------------------------------------
CTID=$(pvesh get /cluster/nextid)
echo "✅ Next available CTID: $CTID"

# ---------------------------------------------------
# FIND / DOWNLOAD DEBIAN 12 TEMPLATE (safe logic)
# ---------------------------------------------------
echo "Checking for Debian 12 templates..."

# Try column 3 (most common)
TEMPLATE=$(pveam list "$STORAGE" | awk '/debian-12-standard/ {print $3; exit}')

# If empty OR not a tar file → try column 2
if [[ -z "$TEMPLATE" || "$TEMPLATE" != *.tar.* ]]; then
    TEMPLATE=$(pveam list "$STORAGE" | awk '/debian-12-standard/ {print $2; exit}')
fi

# If still empty → download latest
if [[ -z "$TEMPLATE" || "$TEMPLATE" != *.tar.* ]]; then
    echo "⏳ No Debian 12 template found — downloading..."
    pveam update >/dev/null
    TEMPLATE=$(pveam available | awk '/debian-12-standard/ {print $2; exit}')
    pveam download "$STORAGE" "$TEMPLATE"
fi

echo "✅ Template filename: $TEMPLATE"

# ---------------------------------------------------
# FINAL TEMPLATE PATH (NO PREFIX CLEANING!)
# ---------------------------------------------------
FINAL_TEMPLATE="${STORAGE}:vztmpl/${TEMPLATE}"
echo "✅ Final template path: $FINAL_TEMPLATE"

# ---------------------------------------------------
# CREATE LXC (Proxmox 9 syntax)
# ---------------------------------------------------
echo "🚀 Creating container..."

pct create $CTID "$FINAL_TEMPLATE" \
    -hostname "$HOSTNAME" \
    -cores "$CORES" \
    -memory "$MEMORY" \
    -rootfs "$STORAGE:${DISK}" \
    -net0 name=eth0,bridge=vmbr0,ip=dhcp \
    -unprivileged "$UNPRIV" \
    -features nesting=1,keyctl=1 \
    -ostype debian \
    -timezone host

echo "✅ Container created"

pct start $CTID
echo "✅ Container started"
sleep 5

# ---------------------------------------------------
# INJECT INSTALLER
# ---------------------------------------------------
pct exec $CTID -- sh -c "apt update && apt install -y curl"
pct exec $CTID -- sh -c "curl -fsSL $REPO/install.sh -o /root/install.sh && chmod +x /root/install.sh"

# ---------------------------------------------------
# RUN INSTALLER
# ---------------------------------------------------
pct exec $CTID -- bash /root/install.sh

IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')

echo ""
echo "========================================="
echo "✅ LXC created and NPM installed!"
echo "➡ Container ID: $CTID"
echo "➡ Access URL: http://$IP:81"
echo "➡ Login: admin@example.com / changeme"
echo "========================================="
