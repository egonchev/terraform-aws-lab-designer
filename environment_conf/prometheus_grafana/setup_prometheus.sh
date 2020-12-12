#!/bin/bash -xe

LOGFILE=/home/${var_os_user}/bootstrap.log
exec &> $LOGFILE

sudo hostnamectl set-hostname ${var_hostname}

echo "${var_os_user} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-cloud-init-users

# Create user accounts for prometheus, alertmanager and node_exporter services
useradd --no-create-home --shell /bin/false prometheus
useradd --no-create-home --shell /bin/false alertmanager
useradd --no-create-home --shell /bin/false node_exporter

mkdir /etc/prometheus /var/lib/prometheus /etc/alertmanager
#mkdir /var/lib/prometheus
#mkdir /etc/alertmanager

# Download prometheus binary files
cd /tmp/
wget https://github.com/prometheus/prometheus/releases/download/v2.23.0/prometheus-2.23.0.linux-amd64.tar.gz
wget https://github.com/prometheus/alertmanager/releases/download/v0.21.0/alertmanager-0.21.0.linux-amd64.tar.gz
wget https://github.com/prometheus/node_exporter/releases/download/v1.0.1/node_exporter-1.0.1.linux-amd64.tar.gz

tar xzf prometheus-2.23.0.linux-amd64.tar.gz
tar xzf alertmanager-0.21.0.linux-amd64.tar.gz
tar xzf node_exporter-1.0.1.linux-amd64.tar.gz

# Install prometheus
cd prometheus-2.23.0.linux-amd64/
mv console* /etc/prometheus
mv prometheus.yml /etc/prometheus
mv prometheus /usr/local/bin/
mv promtool /usr/local/bin/

chown -R prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool /var/lib/prometheus /etc/prometheus
#chown prometheus:prometheus /usr/local/bin/promtool
#chown -R prometheus:prometheus /var/lib/prometheus /etc/prometheus

# Install alertmanager
cd /tmp/alertmanager-0.21.0.linux-amd64/
mv alertmanager /usr/local/bin/
mv amtool /usr/local/bin/
mv alertmanager.yml /etc/alertmanager/

chown -R alertmanager:alertmanager /usr/local/bin/alertmanager /usr/local/bin/amtool /etc/alertmanager/
#chown alertmanager:alertmanager /usr/local/bin/amtool
#chown -R alertmanager:alertmanager /etc/alertmanager/

mv /tmp/node_exporter-1.0.1.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Create Systemd service files and prometheus configuration file
cat << EOF >  /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

cat << EOF >  /etc/systemd/system/alertmanager.service
[Unit]
Description=Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=alertmanager
Group=alertmanager
Type=simple
WorkingDirectory=/etc/alertmanager/
ExecStart=/usr/local/bin/alertmanager \
    --config.file=/etc/alertmanager/alertmanager.yml

[Install]
WantedBy=multi-user.target
EOF

cat << EOF >  /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF


cat << EOF >  /etc/prometheus/prometheus.yml
global:
  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

# Alertmanager configuration
alerting:
  alertmanagers:
  - static_configs:
    - targets:
       - localhost:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
    - targets: ['localhost:9090']
  - job_name: 'alertmanager'
    static_configs:
    - targets: ['localhost:9093']    
  - job_name: 'grafana'
    static_configs:
    - targets: ['10.0.2.10:3000']
  - job_name: 'nodeexporter'
    static_configs:
    - targets: ['localhost:9100',"10.0.2.10:9100"]    
EOF

systemctl daemon-reload 
systemctl enable --now alertmanager.service
systemctl enable --now node_exporter.service
systemctl enable --now prometheus.service
