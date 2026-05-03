#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTORY_FILE="$PROJECT_ROOT/inventory/hosts.ini"

read -rp "web-1 IP: " WEB_IP
read -rp "proxy-1 IP: " PROXY_IP
read -rp "monitor-1 IP: " MONITOR_IP
read -rp "node-4 IP: " NODE4_IP
read -rp "node-5 IP: " NODE5_IP

cat > "$INVENTORY_FILE" <<EOF
[web]
web-1 ansible_host=$WEB_IP

[proxy]
proxy-1 ansible_host=$PROXY_IP

[monitor]
monitor-1 ansible_host=$MONITOR_IP

[nodes]
node-4 ansible_host=$NODE4_IP
node-5 ansible_host=$NODE5_IP

[etcd]
web-1
proxy-1
monitor-1
node-4
node-5

[all:vars]
ansible_user=root
EOF

echo
echo "Inventory updated: $INVENTORY_FILE"
echo
cat "$INVENTORY_FILE"
