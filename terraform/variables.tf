variable "instance_type" {
  description = "Tipo de máquina EC2"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Nome da chave SSH para acessar a instância"
  type        = string
}

variable "ec2_user_data" {
  description = "The user data script to install Docker on the EC2 instance"
  type        = string
  default     = <<-EOF
#!/bin/bash
yum update -y

yum install -y docker
systemctl start docker
systemctl enable docker

# Instalar o Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Criar o Dockerfile
cat << 'DOCKERFILE' > /home/ec2-user/Dockerfile
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
DOCKERFILE

# Construir e executar o container
cd /home/ec2-user
docker build -t zabbix-monitoring .
docker run -d -p 10051:10051 -p 10050:10050 zabbix-monitoring
EOF
}
