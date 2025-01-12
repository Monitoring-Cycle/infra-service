#!/bin/bash
# Script de inicialização para configurar a instância com Docker e Zabbix

yum update -y

sudo yum update -y
sudo yum install -y jq docker


# Enable Docker service
sudo service docker start
sudo usermod -a -G docker ec2-user

# Get the latest version of Docker Compose 
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Criar o Dockerfile
cat << 'EOF' > /home/ec2-user/Dockerfile
FROM amazonlinux:2

RUN yum update -y && \
    yum install -y \
        curl \
        tar \
        unzip \
        sudo \
        vim \
        device-mapper-persistent-data \
        lvm2 && \
    amazon-linux-extras enable docker && \
    yum install -y docker && \
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose && \
    yum clean all

RUN groupadd docker && \
    usermod -aG docker ec2-user

RUN docker pull zabbix/zabbix-server-mysql:latest && \
    docker pull zabbix/zabbix-agent:latest

RUN systemctl enable docker

EXPOSE 2375
EXPOSE 10051 10050

CMD ["/bin/bash"]
EOF

# Construir e executar o container
cd /home/ec2-user
docker build -t zabbix-monitoring .
docker run -d -p 10051:10051 -p 10050:10050 zabbix-monitoring
