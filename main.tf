provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "techcorp-vpc"
  }
}# Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "techcorp-public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "techcorp-public-subnet-2"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "techcorp-private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "techcorp-private-subnet-2"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "techcorp-igw"
  }
}
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "techcorp-public-rt"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}
resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# Elastic IPs for NAT
resource "aws_eip" "nat_eip_1" {
  domain = "vpc"
}

resource "aws_eip" "nat_eip_2" {
  domain = "vpc"
}

# NAT Gateways
resource "aws_nat_gateway" "nat_1" {
  allocation_id = aws_eip.nat_eip_1.id
  subnet_id     = aws_subnet.public_subnet_1.id

  tags = {
    Name = "techcorp-nat-1"
  }
}

resource "aws_nat_gateway" "nat_2" {
  allocation_id = aws_eip.nat_eip_2.id
  subnet_id     = aws_subnet.public_subnet_2.id

  tags = {
    Name = "techcorp-nat-2"
  }
}

resource "aws_route_table" "private_rt_1" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "techcorp-private-rt-1"
  }
}

resource "aws_route" "private_route_1" {
  route_table_id         = aws_route_table.private_rt_1.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_1.id
}

resource "aws_route_table" "private_rt_2" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "techcorp-private-rt-2"
  }
}

resource "aws_route" "private_route_2" {
  route_table_id         = aws_route_table.private_rt_2.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_2.id
}

resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt_1.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt_2.id
}

resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH from my IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web_sg" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name   = "db-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "bastion" {
  ami                         = "ami-0c02fb55956c7d316" # Amazon Linux 2 (us-east-1)
  instance_type               = var.instance_type_bastion
  
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  subnet_id = aws_subnet.public_subnet_1.id
  tags = {
    Name = "techcorp-bastion"
  }
}

resource "aws_instance" "web_1" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = var.instance_type_web
  subnet_id = aws_subnet.public_subnet_1.id
  associate_public_ip_address = true
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = file("user_data/web_server_setup.sh")

  tags = {
    Name = "techcorp-web-1"
  }
}

resource "aws_instance" "web_2" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = var.instance_type_web
  subnet_id = aws_subnet.public_subnet_1.id
  associate_public_ip_address = true
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = file("user_data/web_server_setup.sh")

  tags = {
    Name = "techcorp-web-2"
  }
}

resource "aws_instance" "db" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = var.instance_type_db
  subnet_id = aws_subnet.public_subnet_1.id
  associate_public_ip_address = true
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  user_data = file("user_data/db_server_setup.sh")

  tags = {
    Name = "techcorp-db"
  }
}

resource "aws_lb" "app_lb" {
  name               = "techcorp-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]

  tags = {
    Name = "techcorp-alb"
  }
}

resource "aws_lb_target_group" "tg" {
  name     = "techcorp-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path = "/"
    port = "80"
  }
}

resource "aws_lb_target_group_attachment" "web1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web_2.id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}