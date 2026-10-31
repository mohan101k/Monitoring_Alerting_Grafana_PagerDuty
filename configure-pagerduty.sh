#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$EUID" -eq 0 ]] || { echo "Run with sudo"; exit 1; }
command -v amtool >/dev/null || { echo "Run grafna-promethous.sh first"; exit 1; }
read -rsp "New PagerDuty Events API v2 integration key: " KEY; echo
[[ -n "$KEY" ]] || { echo "Empty key"; exit 1; }
install -d -o prometheus -g prometheus -m 0750 /etc/alertmanager/secrets
printf '%s' "$KEY" > /etc/alertmanager/secrets/pagerduty_routing_key
unset KEY
chown prometheus:prometheus /etc/alertmanager/secrets/pagerduty_routing_key
chmod 0600 /etc/alertmanager/secrets/pagerduty_routing_key
cat > /etc/alertmanager/alertmanager.yml <<'EOF'
route:
  receiver: "pagerduty"
  group_by: ["alertname", "instance"]
  group_wait: 10s
  group_interval: 1m
  repeat_interval: 4h
receivers:
  - name: "pagerduty"
    pagerduty_configs:
      - routing_key_file: "/etc/alertmanager/secrets/pagerduty_routing_key"
        severity: "critical"
        send_resolved: true
EOF
chown prometheus:prometheus /etc/alertmanager/alertmanager.yml
chmod 0640 /etc/alertmanager/alertmanager.yml
amtool check-config /etc/alertmanager/alertmanager.yml
systemctl restart alertmanager
echo "PagerDuty receiver configured."
