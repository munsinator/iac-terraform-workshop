# Author: Your Name
# The provider block is used to let Terraform which provider to use.
# In this case, we are using the AWS provider and specifying the region as "us-east-1".
# Credentials are set as environment variables in the shell and managed by AWS CLI.
provider "aws" {}

# Now we are using th existing VPC and managing its settings.
# In this case, are giving it a name.
resource "aws_default_vpc" "default" {
  tags = {
    Name = "default-VPC"
  }
}

# Now we create a security group that allows inbound traffic on port 80 (HTTP) 
# and allows all outbound traffic. 
resource "aws_security_group" "terraform-ws-1" {
  name        = "workshop-1"
  # The security group is associated with the default VPC we created earlier.
  vpc_id      = aws_default_vpc.default.id

  # Incoming traffic
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    #prefix_list_ids = [data.aws_ec2_managed_prefix_list.instance_connect.id]
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outgoing traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# We need this block to be able to use EC2 Instance Connect to connect to the instance we are creating.
data "aws_ec2_managed_prefix_list" "instance_connect" {
  name = "com.amazonaws.us-east-1.ec2-instance-connect"
}

# This data block is used to fetch the latest Ubuntu AMI from AWS.
data "aws_ami" "ubuntu" {
  most_recent = true
  # The owners field is set to the Canonical account ID (official publisher of Ubuntu AMIs).
  owners      = ["099720109477"] # Canonical
  # The filter is used to specify the name of the AMI we want to fetch. 
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Now wwe create an EC2 instance using the Ubuntu AMI we fetched earlier.
# The instance type is set to "t2.micro" which is eligible for the free tier.
resource "aws_instance" "web_server" {
  ami                         = data.aws_ami.ubuntu.id
  # The instance type is set to "t2.micro" which is free.
  instance_type               = "t2.micro"
  # The security group we created earlier is associated with this instance.
  vpc_security_group_ids      = [aws_security_group.terraform-ws-1.id]
  # Here we are associating a public IP address with the instance so that it can be accessed from the internet.
  associate_public_ip_address = true

  # The user data needed to install Apache on the instance
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