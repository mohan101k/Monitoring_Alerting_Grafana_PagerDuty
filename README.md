# Monitoring Stack: Prometheus, Grafana, Node Exporter, Alertmanager, and PagerDuty


This project provides a simple, script-based setup for a monitoring stack using Prometheus, Grafana, Node Exporter, Alertmanager, and PagerDuty. Each component is managed by a dedicated shell script, making it easy to deploy and run on a Unix-like system. The stack enables not only monitoring and visualization, but also alerting and incident management.
---

<img src="https://github.com/aniljadhavmca/Monitoring-Alerting-Grafana-PagerDuty/blob/main/images/Production%E2%80%91Ready%20EC2%20Observability-1.png" alt="EC2 Observability Architecture" width="800">

### 3. Alertmanager

**Purpose:**

Alertmanager is a core component of the Prometheus ecosystem, responsible for handling alerts sent by Prometheus server. It manages alert notifications, grouping, inhibition, silencing, and routing to various receivers such as email, Slack, or PagerDuty.

**How it fits in:**

- Prometheus is configured to send alerts to Alertmanager based on alerting rules.
- Alertmanager processes these alerts and sends notifications to the configured receivers.

**Typical Workflow:**

1. Prometheus detects an issue (e.g., high CPU usage) based on alerting rules.
2. Prometheus sends the alert to Alertmanager.
3. Alertmanager groups, deduplicates, and routes the alert to the appropriate notification channel.

**Configuration:**

- Alertmanager is usually configured via a YAML file (`alertmanager.yml`) specifying receivers and routing logic.
- Receivers can include email, chat, or incident management platforms like PagerDuty.

---

### 4. PagerDuty Integration

**Purpose:**

PagerDuty is a popular incident management platform that provides real-time alerting, on-call scheduling, and escalation policies. Integrating PagerDuty with Alertmanager allows critical alerts to trigger incidents and notify the right people immediately.

**How it fits in:**

- Alertmanager is configured with a PagerDuty receiver using a service integration key.
- When a critical alert is fired, Alertmanager sends a notification to PagerDuty.
- PagerDuty creates an incident and notifies the on-call engineer via SMS, phone, email, or mobile push.

**Configuration Steps:**

1. Create a service in PagerDuty and obtain the integration key (Events API v2).
2. Add a PagerDuty receiver in `alertmanager.yml`:
    ```yaml
    receivers:
       - name: 'pagerduty'
          pagerduty_configs:
             - routing_key: <YOUR_PAGERDUTY_INTEGRATION_KEY>
    ```
3. Set up routing in Alertmanager to send critical alerts to the PagerDuty receiver.
4. Ensure Prometheus alerting rules are defined for the conditions you want to be paged for.

**Benefits:**

- Automated, reliable alert delivery to the right people.
- Escalation and on-call management.
- Incident tracking and resolution workflows.

---

---

## Components Explained

### 1. Node Exporter (`node.sh`)

**Purpose:**

Node Exporter is an open-source tool that exposes a wide variety of hardware- and kernel-related metrics (CPU, memory, disk, network, etc.) from your system. These metrics are made available via an HTTP endpoint, which Prometheus can scrape for monitoring and alerting.

**How the script works:**

- **Download:** The script fetches the latest Node Exporter binary from the official source.
- **Extract:** It unpacks the downloaded archive.
- **Run:** Node Exporter is started, typically listening on port `9100`.
- **Metrics Endpoint:** Once running, metrics are available at `http://localhost:9100/metrics`.

**Usage:**

```sh
./node.sh
```

**What you get:**

- Real-time system metrics accessible to Prometheus.
- No need for manual installation or configuration—everything is handled by the script.

---

### 2. Prometheus & Grafana (`grafna-promethous.sh`)

**Prometheus**

- **Purpose:** Prometheus is a powerful open-source monitoring and alerting toolkit. It scrapes metrics from Node Exporter and stores them in a time-series database, allowing for querying and alerting.
- **How the script works:**
  - Downloads the Prometheus binary.
  - Extracts and runs Prometheus, usually on port `9090`.
  - The script configures Prometheus to scrape metrics from Node Exporter (on port `9100`).
- **Access:** Prometheus UI is available at `http://localhost:9090`.

**Grafana**

- **Purpose:** Grafana is an open-source analytics and visualization platform. It connects to Prometheus and provides dashboards for visualizing metrics.
- **How the script works:**
  - Downloads the Grafana binary.
  - Extracts and runs Grafana, usually on port `3000`.
  - Grafana can be accessed at `http://localhost:3000` (default login: `admin`/`admin`).
- **Setup:**
  - After starting Grafana, add Prometheus as a data source.
  - Import or create dashboards to visualize your system metrics.

**Usage:**

```sh
./grafna-promethous.sh
```

**What you get:**

- A running Prometheus server scraping metrics from Node Exporter.
- A running Grafana server ready for dashboard creation and visualization.

---


## Step-by-Step Setup

1. **Make scripts executable (if needed):**
   ```sh
   chmod +x node.sh grafna-promethous.sh
   ```
2. **Start Node Exporter:**
   ```sh
   ./node.sh
   ```
3. **Start Prometheus and Grafana:**
   ```sh
   ./grafna-promethous.sh
   ```

4. **Access the services:**
   - Node Exporter: [http://localhost:9100/metrics](http://localhost:9100/metrics)
   - Prometheus: [http://localhost:9090](http://localhost:9090)
   - Grafana: [http://localhost:3000](http://localhost:3000)
   - Alertmanager: [http://localhost:9093](http://localhost:9093) (default port)

5. **Configure Alertmanager and PagerDuty:**
   - Edit `alertmanager.yml` to add your PagerDuty integration key and desired routing.
   - Ensure Prometheus is configured to send alerts to Alertmanager (see `prometheus.yml`).
   - Test alerting by triggering a sample alert and verifying PagerDuty receives the incident.

---

## Prerequisites

- Unix-like OS (Linux, macOS, or WSL on Windows)
- `wget` and `tar` installed
- Sufficient permissions to run scripts and install binaries

---

## Troubleshooting & Tips

- If ports 9100, 9090, or 3000 are in use, stop the conflicting services or change the ports in the scripts.
- For persistent monitoring, consider running the scripts in the background or as system services.
- Grafana default login is `admin`/`admin`. Change the password after first login.
- You can import community dashboards in Grafana for quick visualization.
  ### stress commands
  ```
  sudo apt-get install stress-ng -y   # Ubuntu/Debian
  stress-ng --cpu 2 --timeout 300
`
  ## if you want to create custom dashbord just use these queires
  - For cloudwatch
    ```
    SELECT AVG(CPUUtilization) FROM "AWS/EC2"
    ```

###  for promothious
  ```
  node_cpu_seconds_total{cpu="1"}
  ```

----
  
## Basic PromQL Queries

### CPU Usage %
```promql
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```
Shows CPU usage percentage per instance.

### Memory Usage %
```promql
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)
/ node_memory_MemTotal_bytes * 100
```
Shows memory usage percentage.

### Disk Usage %
```promql
(node_filesystem_size_bytes{fstype!="tmpfs"} - node_filesystem_free_bytes{fstype!="tmpfs"})
/ node_filesystem_size_bytes{fstype!="tmpfs"} * 100
```
Shows disk usage percentage per mount point.

## Load Average (1 minute)
```promql
node_load1
```
Shows system load average (1 minute).

### Network Traffic (Incoming)
```promql
rate(node_network_receive_bytes_total[5m])
```
Shows incoming traffic in bytes/sec.

### Network Traffic (Outgoing)
```promql
rate(node_network_transmit_bytes_total[5m])
```
Shows outgoing traffic in bytes/sec.

### Filter by Specific Instance
```promql
node_load1{instance="10.0.1.10:9100"}
```


### License

MIT License (or specify your license here)
