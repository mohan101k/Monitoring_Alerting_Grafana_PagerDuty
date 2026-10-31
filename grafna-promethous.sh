#!/usr/bin/env bash
set -Eeuo pipefail
PROM_VERSION="2.55.1"
AM_VERSION="0.27.0"
[[ "$EUID" -eq 0 ]] || { echo "Run: sudo bash grafna-promethous.sh"; exit 1; }
. /etc/os-release
[[ "${ID:-}" == ubuntu ]] || { echo "Ubuntu required"; exit 1; }
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in amd64|arm64) GO_ARCH="$ARCH";; *) echo "Unsupported architecture: $ARCH"; exit 1;; esac

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl wget tar gnupg

# Official Grafana repository with signed-by keyring (no deprecated apt-key).
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://apt.grafana.com/gpg-full.key -o /etc/apt/keyrings/grafana.asc
chmod 0644 /etc/apt/keyrings/grafana.asc
cat > /etc/apt/sources.list.d/grafana.list <<'EOF'
deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main
EOF
rm -f /etc/apt/sources.list.d/archive_uri-https_packages_grafana_com_oss_deb-resolute.list
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y grafana

id prometheus >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin prometheus
install -d -o prometheus -g prometheus /etc/prometheus /var/lib/prometheus /etc/alertmanager /var/lib/alertmanager
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fetch(){ curl -fL --retry 3 "$1" -o "$TMP/$2"; tar -xzf "$TMP/$2" -C "$TMP"; }

PDIR="prometheus-${PROM_VERSION}.linux-${GO_ARCH}"
fetch "https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/${PDIR}.tar.gz" "${PDIR}.tar.gz"
systemctl stop prometheus 2>/dev/null || true
install -m 0755 "$TMP/$PDIR/prometheus" /usr/local/bin/prometheus
install -m 0755 "$TMP/$PDIR/promtool" /usr/local/bin/promtool
cp -a "$TMP/$PDIR/consoles" "$TMP/$PDIR/console_libraries" /etc/prometheus/
chown -R prometheus:prometheus /etc/prometheus

ADIR="alertmanager-${AM_VERSION}.linux-${GO_ARCH}"
fetch "https://github.com/prometheus/alertmanager/releases/download/v${AM_VERSION}/${ADIR}.tar.gz" "${ADIR}.tar.gz"
systemctl stop alertmanager 2>/dev/null || true
install -m 0755 "$TMP/$ADIR/alertmanager" /usr/local/bin/alertmanager
install -m 0755 "$TMP/$ADIR/amtool" /usr/local/bin/amtool

cat > /etc/prometheus/prometheus.yml <<'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
alerting:
  alertmanagers:
    - static_configs:
        - targets: ["127.0.0.1:9093"]
rule_files:
  - "/etc/prometheus/alert.rules.yml"
scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["127.0.0.1:9090"]
  - job_name: "node-exporter"
    static_configs:
      - targets: ["127.0.0.1:9100"]
EOF

cat > /etc/prometheus/alert.rules.yml <<'EOF'
groups:
  - name: host-alerts
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Target {{ $labels.instance }} is down"
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU on {{ $labels.instance }}"
      - alert: HighMemoryUsage
        expr: 100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory on {{ $labels.instance }}"
      - alert: HighDiskUsage
        expr: 100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay"}) > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High disk usage on {{ $labels.instance }}"
EOF

cat > /etc/alertmanager/alertmanager.yml <<'EOF'
route:
  receiver: "default"
  group_by: ["alertname", "instance"]
  group_wait: 10s
  group_interval: 1m
  repeat_interval: 4h
receivers:
  - name: "default"
EOF
chown -R prometheus:prometheus /etc/prometheus /etc/alertmanager

cat > /etc/systemd/system/prometheus.service <<'EOF'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target
[Service]
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus --web.console.templates=/etc/prometheus/consoles --web.console.libraries=/etc/prometheus/console_libraries --web.listen-address=0.0.0.0:9090
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/alertmanager.service <<'EOF'
[Unit]
Description=Prometheus Alertmanager
Wants=network-online.target
After=network-online.target
[Service]
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/alertmanager --config.file=/etc/alertmanager/alertmanager.yml --storage.path=/var/lib/alertmanager --web.listen-address=0.0.0.0:9093
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

promtool check config /etc/prometheus/prometheus.yml
amtool check-config /etc/alertmanager/alertmanager.yml
systemctl daemon-reload
systemctl enable --now prometheus alertmanager grafana-server
echo "Installation complete."
echo "Prometheus: http://EC2-PUBLIC-IP:9090"
echo "Grafana: http://EC2-PUBLIC-IP:3000"
echo "Alertmanager: http://EC2-PUBLIC-IP:9093"
echo "Grafana login initially admin/admin; change immediately."
echo "For this tutorial-style setup, run node.sh and this script on the SAME EC2."
echo "Restrict web ports to your IP. Never expose Node Exporter port 9100 publicly."
