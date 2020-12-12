#!/bin/bash -xe

LOGFILE=/home/${var_os_user}/bootstrap.log
exec &> $LOGFILE

sudo hostnamectl set-hostname ${var_hostname}

echo "${var_os_user} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-cloud-init-users

sudo amazon-linux-extras install docker
sudo systemctl enable --now docker
sudo usermod -aG docker ${var_os_user}

timeout 600 bash -c 'until sudo docker swarm join ${var_manager_ip}:2377 --token $(docker -H ${var_manager_ip} swarm join-token -q worker)
do sleep 3; echo "Waiting swarm manager..."
done'
