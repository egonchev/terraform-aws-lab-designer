#!/bin/bash -xe

LOGFILE=/home/${var_os_user}/bootstrap.log
exec &> $LOGFILE

hostnamectl set-hostname ${var_hostname}

echo "${var_os_user} ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/90-cloud-init-users

yum install -y git

cd /tmp/
wget https://dl.grafana.com/oss/release/grafana-7.3.5-1.x86_64.rpm
yum install -y /tmp/grafana-7.3.5-1.x86_64.rpm 

# Configure Prometheus data source and Node Exporter dashboard
cat << EOF >  /etc/grafana/provisioning/datasources/all.yml
apiVersion: 1

datasources:
- name: 'Prometheus'
  type: 'prometheus'
  access: 'proxy'
  org_id: 1
  url: 'http://10.0.1.10:9090'
  is_default: true
  version: 1
  editable: true
EOF

cat << EOF >  /etc/grafana/provisioning/dashboards/dashboard.yml
apiVersion: 1

providers:
  - name: 'Prometheus'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

wget https://raw.githubusercontent.com/rfrail3/grafana-dashboards/master/prometheus/node-exporter-full.json -O /etc/grafana/provisioning/dashboards/node-exporter-full.json

systemctl enable --now grafana-server

# Setup node exporter
useradd --no-create-home --shell /bin/false node_exporter

cd /tmp/
wget https://github.com/prometheus/node_exporter/releases/download/v1.0.1/node_exporter-1.0.1.linux-amd64.tar.gz
tar xzf node_exporter-1.0.1.linux-amd64.tar.gz
mv /tmp/node_exporter-1.0.1.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

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

systemctl daemon-reload 
systemctl enable --now node_exporter.service
