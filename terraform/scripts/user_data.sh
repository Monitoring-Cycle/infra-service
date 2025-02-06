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
chown ubuntu:docker /var/run/docker.sock

echo "🔹 Reiniciando o Docker..."
systemctl restart docker

echo "🔹 Criando rede Docker para os containers Zabbix..."
docker network rm zabbix-net || true  # Remove a rede se já existir
docker network create --subnet=172.20.0.0/16 --ip-range=172.20.240.0/20 zabbix-net

echo "🔹 Criando diretórios para persistência de dados..."
mkdir -p /opt/zabbix/postgres /opt/zabbix/server /opt/zabbix/web /opt/grafana/data

echo "🔹 Ajustando permissões para o Grafana..."
chown 472:472 /opt/grafana/data
chmod 755 /opt/grafana/data

echo "✅ Subindo o container PostgreSQL..."
docker run -d \
  --name postgres-server \
  -e POSTGRES_DB="zabbix" \
  -e POSTGRES_USER="zabbix" \
  -e POSTGRES_PASSWORD="zabbix_pwd" \
  -v /opt/zabbix/postgres:/var/lib/postgresql/data \
  --network=zabbix-net \
  --restart unless-stopped \
  postgres:latest

echo "🔹 Aguardando o PostgreSQL iniciar..."
until docker exec postgres-server pg_isready -U zabbix; do
    sleep 5
    echo "⌛ Aguardando PostgreSQL..."
done
echo "✅ PostgreSQL está pronto!"

echo "✅ Subindo o Zabbix Server..."
docker run -d \
  --name zabbix-server \
  -e DB_SERVER_HOST="postgres-server" \
  -e POSTGRES_USER="zabbix" \
  -e POSTGRES_PASSWORD="zabbix_pwd" \
  -e POSTGRES_DB="zabbix" \
  -v /opt/zabbix/server:/var/lib/zabbix \
  --network=zabbix-net \
  --restart unless-stopped \
  zabbix/zabbix-server-pgsql:latest

echo "🔹 Aguardando o Zabbix Server iniciar..."
sleep 10

echo "✅ Subindo o Zabbix Web Interface..."
docker run -d \
  --name zabbix-web-nginx-pgsql \
  -e ZBX_SERVER_HOST="zabbix-server" \
  -e DB_SERVER_HOST="postgres-server" \
  -e DB_SERVER_TYPE="POSTGRESQL" \
  -e POSTGRES_USER="zabbix" \
  -e POSTGRES_PASSWORD="zabbix_pwd" \
  -e POSTGRES_DB="zabbix" \
  -e PHP_TZ="America/Sao_Paulo" \
  --publish 8080:80 \
  --network=zabbix-net \
  --restart unless-stopped \
  zabbix/zabbix-web-nginx-pgsql:latest

echo "✅ Ajustando permissões no Zabbix Web (Nginx e PHP-FPM)..."
docker exec -u root zabbix-web-nginx-pgsql bash -c "
  chmod 1777 /tmp &&
  chown -R zabbix:zabbix /tmp &&
  mkdir -p /var/run/php &&
  chown zabbix:zabbix /var/run/php &&
  chmod 777 /var/run/php &&
  mkdir -p /var/log &&
  touch /var/log/php-fpm.log &&
  chown zabbix:zabbix /var/log/php-fpm.log &&
  chmod 777 /var/log/php-fpm.log &&
  cat > /etc/php83/php-fpm.d/zabbix.conf <<EOF
[zabbix]
user = zabbix
group = zabbix
listen = 127.0.0.1:9000
listen.owner = zabbix
listen.group = zabbix
listen.mode = 0660

pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 5

php_value[date.timezone] = America/Sao_Paulo
EOF
  echo '
  server {
      listen 80;
      server_name _;

      root /usr/share/zabbix;
      index index.php index.html index.htm;

      location / {
          try_files \$uri \$uri/ =404;
      }

      location ~ \.php$ {
          include fastcgi_params;
          fastcgi_pass 127.0.0.1:9000;
          fastcgi_index index.php;
          fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
      }

      error_log /var/log/nginx/error.log;
      access_log /var/log/nginx/access.log;
  }
  ' > /etc/nginx/http.d/default.conf &&
  nginx -s reload &&
  php-fpm83 -D
"

echo "✅ Subindo o Zabbix Agent..."
docker run -d \
  --name zabbix-agent \
  -e ZBX_SERVER_HOST="zabbix-server" \
  -e ZBX_HOSTNAME="zabbix-agent-ec2" \
  --network=zabbix-net \
  --restart unless-stopped \
  zabbix/zabbix-agent:latest

echo "✅ Subindo o Grafana..."
docker run -d \
  --name grafana \
  -e GF_SECURITY_ADMIN_USER="admin" \
  -e GF_SECURITY_ADMIN_PASSWORD="admin" \
  -v /opt/grafana/data:/var/lib/grafana \
  --publish 3000:3000 \
  --network=zabbix-net \
  --restart unless-stopped \
  grafana/grafana:latest

echo "✅ Configurando firewall para permitir acesso ao Zabbix e Grafana..."
ufw allow 8080/tcp
ufw allow 3000/tcp
ufw enable -y

echo "✅ Verificando containers em execução..."
docker ps

echo "✅ Configuração finalizada!"
echo "🔹 Acesse o Zabbix Web em: http://$(curl -s ifconfig.me):8080"
echo "🔹 Acesse o Grafana em: http://$(curl -s ifconfig.me):3000 (Usuário: admin | Senha: admin)"
