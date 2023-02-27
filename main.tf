provider "aws" {
  region = "us-east-1"
}

#vpc
resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "myVpc"
  }
}

#Private And Public subnets 1,2
resource "aws_subnet" "private_subnet1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1b"
  tags = {
    Name = "PrivateSubnet1"
  }
}

resource "aws_subnet" "private_subnet2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1c"
  tags = {
    Name = "PrivateSubnet2"
  }
}

resource "aws_subnet" "public_subnet1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1b"
  tags = {
    Name = "PublicSubnet1"
  }
}

resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1c"
  tags = {
    Name = "PublicSubnet2"
  }
}

#internet gateway for network connection
resource "aws_internet_gateway" "mygw" {
  vpc_id = aws_vpc.myvpc.id
  tags = {
    Name = "myGw"
  }
}

#elastic ip address for real ip 1,2
resource "aws_eip" "realip1" {
  vpc        = true
  depends_on = [aws_internet_gateway.mygw]
  tags = {
    Name = "realip1"
  }
}
resource "aws_eip" "realip2" {
  vpc        = true
  depends_on = [aws_internet_gateway.mygw]
  tags = {
    Name = "realip2"
  }
}

#nat gateway 1,2 for making the private subnet connect to the internet through the public sub
resource "aws_nat_gateway" "mynatgw1" {
  subnet_id     = aws_subnet.public_subnet1.id
  allocation_id = aws_eip.realip1.id
  tags = {
    Name = "natgw1"
  }
}
resource "aws_nat_gateway" "mynatgw2" {
  subnet_id     = aws_subnet.public_subnet2.id
  allocation_id = aws_eip.realip2.id
  depends_on    = [aws_internet_gateway.mygw]
  tags = {
    Name = "natgw2"
  }
}

#routeing table for public subnets and connect to internet gateway
resource "aws_route_table" "public_rt" {
  vpc_id     = aws_vpc.myvpc.id
  depends_on = [aws_internet_gateway.mygw]
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mygw.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.mygw.id
  }
  tags = {
    Name = "public_rt"
  }
}

#assisate public routeing table with public subnet 1,2
resource "aws_route_table_association" "public_subnet1_ass" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_subnet2_ass" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public_rt.id
}

#for each subnet we make a private routing table to route between nat gatway and private subnet
resource "aws_route_table" "private_rt1" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.mynatgw1.id
  }
  tags = {
    Name = "private_rt1"
  }
}

resource "aws_route_table" "private_rt2" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.mynatgw2.id
  }
  tags = {
    Name = "private_rt2"
  }
}

#assosiate private routing table with private subnet 1,2
resource "aws_route_table_association" "private_subnet1_ass" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.private_rt1.id
}

resource "aws_route_table_association" "private_subnet2_ass" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private_rt2.id
}

#Security group for Loadbalancer And WebServer
resource "aws_security_group" "loadBalancerSecGroup" {
  vpc_id = aws_vpc.myvpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "WebServerSecGroup" {
  vpc_id = aws_vpc.myvpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_configuration" "WebAppLaunchConfig" {
  image_id        = "ami-0557a15b87f6559cf"
  instance_type   = "t3.small"
  security_groups = [aws_security_group.WebServerSecGroup.id]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install apache2 -y
    systemctl start apache2
    cd /var/www/html
    echo "it works! Udagram, Udacity" > index.html
  EOF

  ebs_block_device {
    device_name = "/dev/sdk"
    volume_size = 10
  }



}

resource "aws_lb_target_group" "WebAppTargetGroup" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    timeout             = 8
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}

resource "aws_autoscaling_group" "auto_scale" {
  name = "autoscale"
  vpc_zone_identifier = [
    aws_subnet.private_subnet1.id,
    aws_subnet.private_subnet2.id
  ]
  launch_configuration = aws_launch_configuration.WebAppLaunchConfig.name
  min_size             = 4
  max_size             = 6
  target_group_arns = [
    aws_lb_target_group.WebAppTargetGroup.arn
  ]
}

resource "aws_lb" "WebAppLB" {
  name            = "Web-App-LB"
  security_groups = [aws_security_group.loadBalancerSecGroup.id]
  subnets         = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.WebAppLB.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.WebAppTargetGroup.arn
    type             = "forward"
  }
}

resource "aws_lb_listener_rule" "alblistenerrule" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = 1

  action {
    target_group_arn = aws_lb_target_group.WebAppTargetGroup.arn
    type             = "forward"
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}


