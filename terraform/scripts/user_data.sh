#!/bin/bash

# Atualizar pacotes e instalar dependências
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

# Adicionar chave GPG e repositório oficial do Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Atualizar pacotes novamente e instalar Docker
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Iniciar e habilitar o Docker
systemctl start docker
systemctl enable docker

# Criar o grupo 'docker' se não existir
if ! getent group docker > /dev/null; then
  groupadd docker
fi

# Adicionar o usuário padrão 'ubuntu' ao grupo 'docker'
usermod -aG docker ubuntu

# Ajustar permissões no socket do Docker
chmod 660 /var/run/docker.sock

# Reiniciar o Docker para garantir as permissões
systemctl restart docker

# Criar rede Docker para os containers Zabbix
docker network create --subnet=172.20.0.0/16 --ip-range=172.20.240.0/20 zabbix-net

# Criar diretórios para persistência de dados
mkdir -p /opt/zabbix/mysql /opt/zabbix/server /opt/zabbix/web /opt/grafana/data

# Ajustar permissões para o Grafana
chown 472:472 /opt/grafana/data
chmod 755 /opt/grafana/data

# Subir o container MySQL com volume para persistência
docker run -d \
  --name mysql-server \
  -e MYSQL_DATABASE="zabbix" \
  -e MYSQL_USER="zabbix" \
  -e MYSQL_PASSWORD="zabbix_pwd" \
  -e MYSQL_ROOT_PASSWORD="root_pwd" \
  -v /opt/zabbix/mysql:/var/lib/mysql \
  --network=zabbix-net \
  --restart unless-stopped \
  mysql:8.0-oracle \
  --character-set-server=utf8 \
  --collation-server=utf8_bin \
  --default-authentication-plugin=mysql_native_password

# Subir o container Zabbix Server com volume para persistência
docker run -d \
  --name zabbix-server-mysql \
  -e DB_SERVER_HOST="mysql-server" \
  -e MYSQL_DATABASE="zabbix" \
  -e MYSQL_USER="zabbix" \
  -e MYSQL_PASSWORD="zabbix_pwd" \
  -e MYSQL_ROOT_PASSWORD="root_pwd" \
  -v /opt/zabbix/server:/var/lib/zabbix \
  --network=zabbix-net \
  -p 10051:10051 \
  --restart unless-stopped \
  zabbix/zabbix-server-mysql:alpine-7.2-latest

# Subir o container Zabbix Web Interface com volume para persistência
docker run -d \
  --name zabbix-web-nginx-mysql \
  -e ZBX_SERVER_HOST="zabbix-server-mysql" \
  -e DB_SERVER_HOST="mysql-server" \
  -e MYSQL_DATABASE="zabbix" \
  -e MYSQL_USER="zabbix" \
  -e MYSQL_PASSWORD="zabbix_pwd" \
  -e MYSQL_ROOT_PASSWORD="root_pwd" \
  -e PHP_TZ="America/Sao_Paulo" \
  -v /opt/zabbix/web:/usr/share/zabbix \
  --network=zabbix-net \
  -p 8080:80 \
  --restart unless-stopped \
  zabbix/zabbix-web-nginx-mysql:alpine-7.2-latest

# Subir o container Zabbix Agent
docker run -d \
  --name zabbix-agent \
  -e ZBX_SERVER_HOST="zabbix-server-mysql" \
  -e ZBX_HOSTNAME="zabbix-agent-ec2" \
  --network=zabbix-net \
  --restart unless-stopped \
  zabbix/zabbix-agent:alpine-7.2-latest

# Subir o container Grafana com volume para persistência e permissões corrigidas
docker run -d \
  --name grafana \
  -e GF_SECURITY_ADMIN_USER="admin" \
  -e GF_SECURITY_ADMIN_PASSWORD="admin" \
  -v /opt/grafana/data:/var/lib/grafana \
  -p 3000:3000 \
  --network=zabbix-net \
  --restart unless-stopped \
  grafana/grafana:latest

# Instalar Node.js e dependências
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt-get install -y nodejs

# Configuração adicional para aplicativos Node.js (se necessário)
mkdir -p /var/www/myapp
cd /var/www/myapp
npm init -y
npm install express

# Mensagem de conclusão
echo "Configuração do Zabbix, Zabbix Agent, Grafana e ambiente Node.js concluída!"
echo "Acesse a interface web do Zabbix em http://<IP_DO_SERVIDOR>:8080"
echo "Acesse a interface do Grafana em http://<IP_DO_SERVIDOR>:3000 (Usuário: admin | Senha: admin)"
