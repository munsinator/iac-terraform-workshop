# Author: Your Name
# The provider block is used to let Terraform which provider to use.
# Credentials & region are set as environment variables in the shell and managed by AWS CLI.
provider "aws" {}

# Now we are using the existing VPC and managing its settings.
# In this case, are giving it a name.
resource "aws_default_vpc" "default" {
  tags = {
    Name = "default-VPC"
  }
}

# Creating a new "custom" VPC
resource "aws_vpc" "tf-workshop-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tf-workshop-VPC"
  }
}

# Now we are creating an internet gateway and associating it with the VPC we created earlier.
resource "aws_internet_gateway" "tf-igw" {
  vpc_id = aws_vpc.tf-workshop-vpc.id

  tags = {
    Name = "tf-igw"
  }
}

# Now we are creating a route table and associating it with the VPC we created earlier.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.tf-workshop-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf-igw.id
  }

  tags = {
    Name = "workshop-public-routes"
  }
}

# Now we are creating just one public subnet in the VPC we created earlier.

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.tf-workshop-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "workshop-public-subnet"
  }
}

# Now we are creating a route table and associating it with the public subnet we created earlier.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Now we create a security group that allows inbound traffic on port 80 (HTTP) 
# and allows all outbound traffic. 
resource "aws_security_group" "terraform-ws-1" {
  name        = "workshop-1"
  # The security group is associated with the default VPC we created earlier. For part 2: we switched to the custom VPC.
  vpc_id      = aws_vpc.tf-workshop-vpc.id

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

# Now we create an EC2 instance using the Ubuntu AMI we fetched earlier.
# The instance type is set to "t2.micro" which is eligible for the free tier.
resource "aws_instance" "web_server" {
  ami                         = data.aws_ami.ubuntu.id
  # The instance type is set to "t2.micro" which is free.
  instance_type               = "t2.micro"
  # The security group we created earlier is associated with this instance.
  # vpc_security_group_ids      = [aws_security_group.terraform-ws-1.id]
  # Here we are associating a public IP address with the instance so that it can be accessed from the internet.
  # associate_public_ip_address = true

  # Connects the EC2 instance to the network interface we created earlier. This is necessary because we are using a custom VPC and a public subnet.
  network_interface {
    network_interface_id = aws_network_interface.web.id
    device_index         = 0
  }

  # The user data needed to install Apache on the instance
  user_data = file("./install_apache.sh")

  depends_on = [
    aws_eip.webserver,
    aws_route_table_association.public
  ]

  tags = {
    Name = "webserver"
  }
}

# Now we are creating a network interface and associating it with the public subnet.
resource "aws_network_interface" "web" {
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.terraform-ws-1.id]

  tags = {
    Name = "workshop-web-interface"
  }
}

# Now we are creating an Elastic IP and associating it with the ENI.
resource "aws_eip" "webserver" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.web.id

  depends_on = [aws_internet_gateway.tf-igw]

  tags = {
    Name = "tf-workshop-web-eip"
  }
}