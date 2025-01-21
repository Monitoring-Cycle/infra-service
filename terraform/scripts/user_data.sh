#!/bin/bash
set -e  # Interrompe a execução em caso de erro

### Passo 1 - Atualizar pacotes e instalar dependências ###
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common nginx docker.io

# Iniciar o serviço Docker
systemctl start docker
systemctl enable docker

# Adicionar o usuário 'ubuntu' ao grupo 'docker' para evitar problemas de permissão
usermod -aG docker ubuntu

### Passo 2 - Configurar o NGINX como Proxy Reverso para o Zabbix ###
cat <<EOF > /etc/nginx/sites-available/default
# Configuração do NGINX para Zabbix
server {
    listen 80;

    location / {
        proxy_pass http://127.0.0.1:8081;  # Redireciona para o Zabbix Web
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Reiniciar o NGINX para aplicar as alterações
systemctl restart nginx

### Passo 3 - Configurar Contêineres do Zabbix ###
# Subir o banco de dados do Zabbix
docker run -d --name zabbix-db -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=zabbix \
  --health-cmd="pg_isready -U postgres" --health-interval=10s --health-timeout=5s --health-retries=3 \
  postgres:latest

# Subir o Zabbix Server
docker run -d --name zabbix-server --link zabbix-db:zabbix-db -p 10051:10051 \
  -e DB_SERVER_HOST=zabbix-db -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=zabbix \
  --health-cmd="zabbix_server -R config_cache_reload" --health-interval=10s --health-timeout=5s --health-retries=3 \
  zabbix/zabbix-server-pgsql:latest

# Subir o Zabbix Web Interface
docker run -d --name zabbix-web --link zabbix-server:zabbix-server --link zabbix-db:zabbix-db -p 8081:8080 \
  -e ZBX_SERVER_HOST=zabbix-server -e DB_SERVER_HOST=zabbix-db \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=zabbix \
  zabbix/zabbix-web-nginx-pgsql:latest

# Subir o Zabbix Agent
docker run -d --name zabbix-agent --link zabbix-server:zabbix-server \
  -e ZBX_SERVER_HOST=zabbix-server zabbix/zabbix-agent:latest

### Passo 4 - Verificar Configurações ###
echo "==== Containers em Execução ===="
docker ps

### Passo 5 - Verificar Logs (Opcional para Debug) ###
echo "==== Logs dos Contêineres ===="
docker logs zabbix-db
docker logs zabbix-server
docker logs zabbix-web
