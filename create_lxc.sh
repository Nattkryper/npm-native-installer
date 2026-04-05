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
# FIND / DOWNLOAD TEMPLATE (PVE 8 & 9 compatible)
# ---------------------------------------------------
echo "Checking for Debian 12 templates..."

# Extract correct filename (column 3 normally, fallback to 2)
RAW_TEMPLATE_LINE=$(pveam list $STORAGE | grep -m1 "debian-12-standard" || true)

if [ -n "$RAW_TEMPLATE_LINE" ]; then
    # Try filename in $3
    TEMPLATE=$(echo "$RAW_TEMPLATE_LINE" | awk '{print $3}')
    # If $3 is empty or looks like a size, try $2
    if [[ -z "$TEMPLATE" || "$TEMPLATE" =~ MB$ || "$TEMPLATE" =~ GB$ ]]; then
        TEMPLATE=$(echo "$RAW_TEMPLATE_LINE" | awk '{print $2}')
    fi
else
    TEMPLATE=""
fi

# If STILL empty, must download it
if [ -z "$TEMPLATE" ] || [[ "$TEMPLATE" != *.tar.* ]]; then
    echo "⏳ No Debian 12 template found — downloading latest..."
    pveam update >/dev/null
    TEMPLATE=$(pveam available | awk '/debian-12-standard/ {print $2; exit}')
    pveam download $STORAGE $TEMPLATE
fi

echo "✅ Template found: $TEMPLATE"

# ---------------------------------------------------
# CORRECT TEMPLATE PATH FOR pct (avoid double prefixes)
# ---------------------------------------------------
# pveam list prints:   local    vztmpl    debian-12...
# pct create needs:    local:vztmpl/debian-12...

# If TEMPLATE already includes 'local:' strip it
CLEAN_TEMPLATE="$TEMPLATE"
CLEAN_TEMPLATE="${CLEAN_TEMPLATE#local:}"      # remove leading local:
CLEAN_TEMPLATE="${CLEAN_TEMPLATE#vztmpl/}"     # remove leading vztmpl/

# Final correct template path:
FINAL_TEMPLATE="${STORAGE}:vztmpl/${CLEAN_TEMPLATE}"

echo "✅ Final template path: $FINAL_TEMPLATE"

# ---------------------------------------------------
# CREATE LXC (Proxmox 9 syntax)
# ---------------------------------------------------
echo "🚀 Creating container..."

pct create $CTID "$FINAL_TEMPLATE" \
    -hostname $HOSTNAME \
    -cores $CORES \
    -memory $MEMORY \
    -rootfs $STORAGE:${DISK} \
    -net0 name=eth0,bridge=vmbr0,ip=dhcp \
    -unprivileged $UNPRIV \
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
