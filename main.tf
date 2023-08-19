provider "aws" {
  region = "us-east-2"
} 
data "aws_availability_zones" "available" {
  state = "available"
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Main VPC"
  }
}

# Create 3 subnets in the VPC
resource "aws_subnet" "subnets" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = count.index < 2 ? true : false

  tags = {
    Name = "Subnet-${count.index}" 
  }
}
# Create Internet Gateway and attach to VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw"
  }
}

# Create route table and add public route
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Private Route Table"
  }
}

resource "aws_route_table_association" "public" {
  count = 2
  
  subnet_id      = element(aws_subnet.subnets[*].id, count.index) 
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.subnets[2].id
  route_table_id = aws_route_table.private.id
}

# Create security group for web traffic
resource "aws_security_group" "web" {
  name   = "WebSG"
  vpc_id = aws_vpc.main.id

  # Ingress rules for ports 22, 80, 443, 8080
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Create Launch Configuration
resource "aws_launch_configuration" "my_config" {
  name          = "MyLaunchConfig"
  image_id      = "ami-024e6efaf93d85776"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.web.id]

  user_data = <<-EOT
                #!/bin/bash
                sudo snap install docker 
                sudo apt install git
                sudo docker pull projiadt/weeb:final
                sudo docker run -d -p 8080:80 projiadt/weeb:final
                sudo wget https://raw.githubusercontent.com/finalprojiadt/iadt/main/cpu.py
                sudo wget https://raw.githubusercontent.com/finalprojiadt/iadt/main/mykey.pub
                sudo cat /mykey.pub >> /home/ubuntu/.ssh/authorized_keys
                EOT

  lifecycle {
    create_before_destroy = true
  }
}

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name   = "ALB_SG"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.subnets[0].id, aws_subnet.subnets[1].id]

  enable_deletion_protection         = false
  enable_cross_zone_load_balancing   = true
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_tg.arn
  }
}

resource "aws_lb_target_group" "my_tg" {
  name     = "my-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

# Create AutoScaling Group
resource "aws_autoscaling_group" "my_asg" {
  launch_configuration = aws_launch_configuration.my_config.name
  min_size             = 1
  max_size             = 5
  desired_capacity     = 1
  vpc_zone_identifier  = [aws_subnet.subnets[0].id, aws_subnet.subnets[1].id] 
  target_group_arns = [aws_lb_target_group.my_tg.arn]

  tag {
    key                 = "Name"
    value               = "MyAutoScalingGroup"
    propagate_at_launch = true
  }
}

# Scale up policy
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 180
  autoscaling_group_name = aws_autoscaling_group.my_asg.name
}

# Scale down policy
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 180
  autoscaling_group_name = aws_autoscaling_group.my_asg.name
}

# CloudWatch Alarm to scale up
resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name          = "scale-up-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "30"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric triggers when CPU usage exceeds 70%"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
}

# CloudWatch Alarm to scale down
resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_name          = "scale-down-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "30"
  statistic           = "Average"
  threshold           = "40"
  alarm_description   = "This metric triggers when CPU usage falls below 40%"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
}
