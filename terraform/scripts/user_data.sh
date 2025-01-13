#!/bin/bash
# Atualizar pacotes e instalar dependências
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Adicionar chave GPG e repositório oficial do Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Atualizar pacotes novamente e instalar Docker
apt-get update -y
apt-get install -y docker-ce

# Iniciar e habilitar o Docker
systemctl start docker
systemctl enable docker

# Pré-download da imagem do Zabbix
docker pull zabbix/zabbix-appliance:latest

# Subir o container Zabbix
docker run -d \
  --name zabbix-server \
  -p 8080:80 \
  -p 10051:10051 \
  zabbix/zabbix-appliance:latest

# Verificar se o container foi iniciado corretamente
docker ps | grep zabbix-server
