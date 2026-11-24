# Author: Your Name
# The provider block is used to let Terraform which provider to use.
# In this case, we are using the AWS provider and specifying the region as "us-east-1".
# Credentials are set as environment variables in the shell and managed by AWS CLI.
provider "aws" {
  region = "us-east-1"
}

# Now we are u
resource "aws_default_vpc" "default" {
  tags = {
    Name = "default-VPC"
  }
}

# Now we create a security group that allows inbound traffic on port 80 (HTTP) 
# and allows all outbound traffic. 
resource "aws_security_group" "terraform-ws-1" {
  name        = "workshop-1"
  vpc_id      = aws_default_vpc.default.id

  # Incoming traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }
  # Outgoing traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_instance" "web_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.terraform-ws-1.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo systemctl enable apache2
              echo "<h1>Hello World</h1>" | sudo tee /var/www/html/index.html
  EOF

  tags = {
    Name = "webserver"
  }
}