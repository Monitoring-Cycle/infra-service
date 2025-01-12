# Escolha uma imagem base oficial e leve
FROM amazonlinux:2

# Atualize o sistema e instale dependências
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

# Adicione o usuário atual ao grupo docker
RUN groupadd docker && \
    usermod -aG docker ec2-user

# Inicie o Docker automaticamente
RUN systemctl enable docker

# Exponha a porta padrão do Docker
EXPOSE 2375

# Comando padrão para iniciar o Docker
CMD ["/bin/bash"]
