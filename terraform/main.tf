resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "MyTerraformVPC"
  }
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "MyTerraformSubnet"
  }
}

# Adicionar um Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "MyInternetGateway"
  }
}

# Configurar a Tabela de Rotas
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

resource "aws_security_group" "ssh_access" {
  name   = "allow_ssh"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "SSHAccessGroup"
  }
}




resource "aws_security_group_rule" "allow_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ssh_access.id
}

data "template_file" "user_data" {
  template = file("./scripts/user_data.sh")

}

resource "aws_instance" "ec2_instance" {
  ami                    = "ami-05576a079321f21f8"
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.ssh_access.id]

  associate_public_ip_address = true



  tags = {
    Name = "NadinMachine"
  }
}
