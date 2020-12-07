#!/bin/bash -xe

LOGFILE=/home/${var_os_user}/bootstrap.log
exec &> $LOGFILE

sudo hostnamectl set-hostname ${var_hostname}

echo "${var_os_user} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-cloud-init-users

sudo amazon-linux-extras install docker

sudo sed -i 's#-H fd://#-H fd:// -H unix:///var/run/docker.sock -H tcp://0.0.0.0:2375#g' /usr/lib/systemd/system/docker.service
sudo systemctl daemon-reload

sudo systemctl enable --now docker
sudo usermod -aG docker ${var_os_user}
sudo docker swarm init

timeout 300 bash -c 'until docker node ls | egrep "db.*Active" && docker node ls | egrep "wordpress.*Active"
do sleep 5; echo "Waiting worker nodes..."
done'

cat << EOF >  ./docker-compose.yml
version: '3.3'
services:

   portainer:
     image: portainer/portainer
     command: -H unix:///var/run/docker.sock     
     deploy:
       mode: replicated
       replicas: 1     
       placement:
         constraints:
           - "node.role == manager"
     ports:
       - "9000:9000"
       - "8000:8000"       
     restart: always
     volumes:
       - /var/run/docker.sock:/var/run/docker.sock
       - portainer_data:/data
       
   db:
     image: mysql:5.7
     deploy:
       placement:
         constraints:
           - "node.hostname==db"
     volumes:
       - db_data:/var/lib/mysql
     restart: always
     environment:
       MYSQL_ROOT_PASSWORD: somewordpress
       MYSQL_DATABASE: wordpress
       MYSQL_USER: wordpress
       MYSQL_PASSWORD: wordpress

   wordpress:
     depends_on:
       - db
     image: wordpress:latest
     deploy:
       placement:
         constraints:
           - "node.hostname==wordpress"
     ports:
       - "443:80"
     restart: always
     environment:
       WORDPRESS_DB_HOST: db:3306
       WORDPRESS_DB_USER: wordpress
       WORDPRESS_DB_PASSWORD: wordpress
       WORDPRESS_DB_NAME: wordpress

volumes:
    db_data: {}
    portainer_data: {}
EOF
    
sudo docker stack deploy -c docker-compose.yml app
