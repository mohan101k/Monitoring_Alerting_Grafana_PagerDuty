#!/bin/bash
set -e

echo "=============================="
echo " Installing Alertmanager + Node Exporter"
echo "=============================="

# ============ 1. Install Alertmanager ============
echo "[*] Downloading Alertmanager..."
cd /tmp
curl -LO https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz
tar -xvf alertmanager-0.27.0.linux-amd64.tar.gz
cd alertmanager-0.27.0.linux-amd64

echo "[*] Installing Alertmanager binaries..."
sudo cp alertmanager amtool /usr/local/bin/
sudo mkdir -p /etc/alertmanager /var/lib/alertmanager
sudo cp alertmanager.yml /etc/alertmanager/
sudo chown -R nobody:nogroup /etc/alertmanager /var/lib/alertmanager

echo "[*] Creating systemd service for Alertmanager..."
sudo tee /etc/systemd/system/alertmanager.service >/dev/null <<'EOF'
[Unit]
Description=Alertmanager
After=network.target

[Service]
User=nobody
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager/
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl enable --now alertmanager

echo ">>> Alertmanager installed and running on port 9093"

# ============ 2. Install Node Exporter ============
echo "[*] Creating node_exporter user..."
sudo useradd --no-create-home --shell /bin/false node_exporter || true

echo "[*] Downloading Node Exporter..."
cd /tmp
curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar -xvf node_exporter-1.8.2.linux-amd64.tar.gz
cd node_exporter-1.8.2.linux-amd64

echo "[*] Installing Node Exporter binary..."
sudo cp node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

echo "[*] Creating systemd service for Node Exporter..."
sudo tee /etc/systemd/system/node_exporter.service >/dev/null <<'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl enable --now node_exporter

echo "[*] Updating system packages..."
sudo apt update && sudo apt upgrade -y

echo ">>> Node Exporter installed and running on port 9100"

echo "=============================="
echo " Installation Completed ✅"
echo "=============================="
