#!/bin/bash
set -e  # Para interromper a execução em caso de erro

### Passo 1 - Atualizar pacotes e instalar dependências ###
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common

### Passo 2 - Instalar Docker e Docker Compose ###
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update -y
apt-get install -y docker-ce docker-compose

### Passo 3 - Configurar Docker ###
systemctl start docker
systemctl enable docker

# Criar o grupo 'docker' e adicionar o usuário padrão
if ! getent group docker > /dev/null; then
  groupadd docker
fi
usermod -aG docker ubuntu
chmod 660 /var/run/docker.sock
systemctl restart docker

### Passo 4 - Criar Rede Bridge para Zabbix ###
docker network create --driver bridge zabbix-network

### Passo 5 - Deploy do Banco de Dados MySQL ###
docker pull mysql:8.0
docker run -d --name mysql-server \
  --network zabbix-network \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  -e MYSQL_DATABASE=zabbix \
  -e MYSQL_USER=zabbix \
  -e MYSQL_PASSWORD=zabbixpass \
  -p 3306:3306 \
  --restart always \
  mysql:8.0

### Passo 6 - Deploy do Zabbix Server ###
docker pull zabbix/zabbix-server-mysql:latest
docker run -d --name zabbix-server \
  --network zabbix-network \
  -p 10051:10051 -p 10050:10050 \
  -e DB_SERVER_HOST="mysql-server" \
  -e MYSQL_USER="zabbix" \
  -e MYSQL_PASSWORD="zabbixpass" \
  --restart always \
  zabbix/zabbix-server-mysql:latest

### Passo 7 - Deploy do Zabbix Web Interface ###
docker pull zabbix/zabbix-web-nginx-mysql:latest
docker run -d --name zabbix-web \
  --network zabbix-network \
  -p 80:80 \
  -e DB_SERVER_HOST="mysql-server" \
  -e MYSQL_USER="zabbix" \
  -e MYSQL_PASSWORD="zabbixpass" \
  -e ZBX_SERVER_HOST="zabbix-server" \
  -e PHP_TZ="America/Sao_Paulo" \
  --restart always \
  zabbix/zabbix-web-nginx-mysql:latest

### Passo 8 - Deploy do Zabbix Agent ###
docker pull zabbix/zabbix-agent:latest
docker run -d --name zabbix-agent \
  --network zabbix-network \
  -e ZBX_HOSTNAME="Zabbix-Agent-Server" \
  -e ZBX_SERVER_HOST="zabbix-server" \
  --restart always \
  zabbix/zabbix-agent:latest

### Passo 9 - Criar Arquivos de Configuração para docker-compose ###
mkdir -p /opt/zabbix && cd /opt/zabbix

cat <<EOF > docker-compose.yml
version: '3'
networks:
  zabbix-network:
    driver: bridge

services:
  mysql-server:
    image: mysql:8.0
    restart: always
    networks:
      - zabbix-network
    environment:
      MYSQL_ROOT_PASSWORD: rootpass
      MYSQL_DATABASE: zabbix
      MYSQL_USER: zabbix
      MYSQL_PASSWORD: zabbixpass
    ports:
      - "3306:3306"

  zabbix-server:
    image: zabbix/zabbix-server-mysql:latest
    restart: always
    networks:
      - zabbix-network
    environment:
      DB_SERVER_HOST: mysql-server
      MYSQL_USER: zabbix
      MYSQL_PASSWORD: zabbixpass
    ports:
      - "10051:10051"
      - "10050:10050"
    depends_on:
      - mysql-server

  zabbix-web:
    image: zabbix/zabbix-web-nginx-mysql:latest
    restart: always
    networks:
      - zabbix-network
    environment:
      DB_SERVER_HOST: mysql-server
      MYSQL_USER: zabbix
      MYSQL_PASSWORD: zabbixpass
      ZBX_SERVER_HOST: zabbix-server
      PHP_TZ: America/Sao_Paulo
    ports:
      - "80:80"
    depends_on:
      - zabbix-server

  zabbix-agent:
    image: zabbix/zabbix-agent:latest
    restart: always
    networks:
      - zabbix-network
    environment:
      ZBX_HOSTNAME: Zabbix-Agent-Server
      ZBX_SERVER_HOST: zabbix-server
    depends_on:
      - zabbix-server
EOF

### Passo 10 - Subir os Containers com docker-compose ###
docker-compose up -d

### Passo 11 - Verificar Status ###
echo "==== Docker Containers em Execução ===="
docker ps

echo "Zabbix e MySQL foram configurados com sucesso! O Zabbix Web está disponível na porta 80."
