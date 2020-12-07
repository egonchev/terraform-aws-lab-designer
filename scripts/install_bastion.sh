#!/bin/bash -xe

LOGFILE=/home/${var_os_user}/LogFile.log
exec &> $LOGFILE

sudo hostnamectl set-hostname ${var_hostname}

echo "${var_os_user} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-cloud-init-users

