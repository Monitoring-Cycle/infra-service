# Criar a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "MyTerraformVPC"
  }
}

# Criar a Sub-rede
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "MyTerraformSubnet"
  }
}

# Criar o Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "MyInternetGateway"
  }
}

# Criar a Tabela de Rotas
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "MyRouteTable"
  }
}

# Associar a Tabela de Rotas à Sub-rede
resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# Criar o Security Group para SSH
resource "aws_security_group" "ssh_access" {
  name   = "allow_ssh"
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "SSHAccessGroup"
  }
}

# Regras de Segurança para SSH
resource "aws_security_group_rule" "allow_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ssh_access.id
}

# Criar o Security Group para Zabbix
resource "aws_security_group" "zabbix_access" {
  name   = "zabbix_access"
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "ZabbixAccessGroup"
  }
}

# Regras de Segurança para Porta 80 (Web Interface do Zabbix)
resource "aws_security_group_rule" "allow_zabbix_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.zabbix_access.id
}

# Regras de Segurança para Porta 10051 (Zabbix Server)
resource "aws_security_group_rule" "allow_zabbix_server" {
  type              = "ingress"
  from_port         = 10051
  to_port           = 10051
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.zabbix_access.id
}

# Template File para o Script de User Data
data "template_file" "user_data" {
  template = file("./scripts/user_data.sh")
}

# Criar a Instância EC2 com o Script de User Data
resource "aws_instance" "ec2_instance" {
  ami           = "ami-0e2c8caa4b6378d8c" # AMI Ubuntu 24.04
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = aws_subnet.main.id
  vpc_security_group_ids = [
    aws_security_group.ssh_access.id,
    aws_security_group.zabbix_access.id
  ]

  associate_public_ip_address = true

  # Adicionar o script de User Data
  user_data = data.template_file.user_data.rendered

  tags = {
    Name = "ZabbixMachine"
  }
}
