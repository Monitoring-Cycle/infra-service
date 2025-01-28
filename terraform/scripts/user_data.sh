#!/bin/bash

set -e  # Interrompe o script em caso de erro

echo "🔹 Atualizando pacotes e instalando dependências..."
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release ufw

echo "🔹 Adicionando chave GPG e repositório oficial do Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

echo "🔹 Instalando Docker e Docker Compose..."
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "🔹 Iniciando e habilitando o Docker..."
systemctl start docker
systemctl enable docker

echo "🔹 Criando grupo 'docker' e ajustando permissões..."
if ! getent group docker > /dev/null; then
  groupadd docker
fi
usermod -aG docker ubuntu
chmod 666 /var/run/docker.sock

echo "🔹 Reiniciando o Docker..."
systemctl restart docker

echo "🔹 Criando rede Docker para os containers Zabbix..."
docker network create --subnet=172.20.0.0/16 --ip-range=172.20.240.0/20 zabbix-net || true

echo "🔹 Criando diretórios para persistência de dados..."
mkdir -p /opt/zabbix/mysql /opt/zabbix/server /opt/zabbix/web /opt/grafana/data

echo "🔹 Ajustando permissões para o Grafana..."
chown 472:472 /opt/grafana/data
chmod 755 /opt/grafana/data

echo "✅ Subindo o container MySQL..."
docker run -d \
  --name mysql-server \
  -e MYSQL_DATABASE="zabbix" \
  -e MYSQL_USER="zabbix" \
  -e MYSQL_PASSWORD="zabbix_pwd" \
  -e MYSQL_ROOT_PASSWORD="root_pwd" \
  -v /opt/zabbix/mysql:/var/lib/mysql \
  --network=zabbix-net \
  --restart unless-stopped \
  mysql:8.0 \
  --character-set-server=utf8mb4 \
  --collation-server=utf8mb4_unicode_ci \
  --default-authentication-plugin=mysql_native_password

echo "🔹 Aguardando o MySQL iniciar..."
until docker exec mysql-server mysqladmin ping -h "localhost" --silent; do
    sleep 5
    echo "⌛ Aguardando MySQL..."
done
echo "✅ MySQL está pronto!"

echo "✅ Subindo o Zabbix Server..."
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
  --default-authentication-plugin=mysql_native_password \
  --ssl=0

echo "🔹 Aguardando o Zabbix Server iniciar..."
until docker logs zabbix-server-mysql 2>&1 | grep -q "Starting Zabbix Server"; do
    sleep 5
    echo "⌛ Aguardando Zabbix Server..."
done
echo "✅ Zabbix Server está pronto!"

echo "✅ Subindo o Zabbix Web Interface..."
docker run -d \
  --name zabbix-web-nginx-mysql \
  -e ZBX_SERVER_HOST="zabbix-server-mysql" \
  -e DB_SERVER_HOST="mysql-server" \
  -e MYSQL_DATABASE="zabbix" \
  -e MYSQL_USER="zabbix" \
  -e MYSQL_PASSWORD="zabbix_pwd" \
  -e MYSQL_ROOT_PASSWORD="root_pwd" \
  -e PHP_TZ="America/Sao_Paulo" \
  -p 8080:80 \
  --network=zabbix-net \
  --restart unless-stopped \
  zabbix/zabbix-web-nginx-mysql:alpine-7.2-latest

echo "✅ Subindo o Zabbix Agent..."
docker run -d \
  --name zabbix-agent \
  -e ZBX_SERVER_HOST="zabbix-server-mysql" \
  -e ZBX_HOSTNAME="zabbix-agent-ec2" \
  --network=zabbix-net \
  --restart unless-stopped \
  zabbix/zabbix-agent:alpine-7.2-latest

echo "✅ Subindo o Grafana..."
docker run -d \
  --name grafana \
  -e GF_SECURITY_ADMIN_USER="admin" \
  -e GF_SECURITY_ADMIN_PASSWORD="admin" \
  -v /opt/grafana/data:/var/lib/grafana \
  -p 3000:3000 \
  --network=zabbix-net \
  --restart unless-stopped \
  grafana/grafana:latest

echo "✅ Configurando firewall para permitir acesso ao Zabbix e Grafana..."
ufw allow 8080/tcp
ufw allow 3000/tcp

echo "✅ Verificando containers em execução..."
docker ps

echo "✅ Configuração finalizada!"
echo "🔹 Acesse o Zabbix Web em: http://$(curl -s ifconfig.me):8080"
echo "🔹 Acesse o Grafana em: http://$(curl -s ifconfig.me):3000 (Usuário: admin | Senha: admin)"

