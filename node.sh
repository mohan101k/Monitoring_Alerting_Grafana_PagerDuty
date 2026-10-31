#!/usr/bin/env bash
set -Eeuo pipefail
VERSION="1.8.2"
[[ "$EUID" -eq 0 ]] || { echo "Run: sudo bash node.sh"; exit 1; }
. /etc/os-release
[[ "${ID:-}" == ubuntu ]] || { echo "Ubuntu required"; exit 1; }
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in amd64|arm64) ;; *) echo "Unsupported architecture: $ARCH"; exit 1;; esac

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y curl tar
id node_exporter >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin node_exporter

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FILE="node_exporter-${VERSION}.linux-${ARCH}.tar.gz"
curl -fL --retry 3 "https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/${FILE}" -o "$TMP/$FILE"
tar -xzf "$TMP/$FILE" -C "$TMP"
systemctl stop node_exporter 2>/dev/null || true
install -m 0755 "$TMP/node_exporter-${VERSION}.linux-${ARCH}/node_exporter" /usr/local/bin/node_exporter

cat > /etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target
[Service]
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9100
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now node_exporter
echo "Node Exporter active: http://localhost:9100/metrics"
