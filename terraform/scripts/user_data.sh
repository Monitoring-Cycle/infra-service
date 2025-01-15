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

# Mensagem de conclusão
echo "Docker e Zabbix foram configurados com sucesso. Por favor, reconecte-se para aplicar as permissões ao grupo docker."
