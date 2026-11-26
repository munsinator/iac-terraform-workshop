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

# Now we are creating just another public subnet in the VPC we created earlier.

resource "aws_subnet" "public-2" {
  vpc_id            = aws_vpc.tf-workshop-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "workshop-public-subnet-2"
  }
}

# Now we are creating route tables and associating it with the public subnets we created earlier.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public-2" {
  subnet_id      = aws_subnet.public-2.id
  route_table_id = aws_route_table.public.id
}

# Now we create security groups that allows inbound traffic on port 80 (HTTP) 
# and allows all outbound traffic. 
resource "aws_security_group" "terraform-ws-1" {
  name = "workshop-1"
  # The security group is associated with the default VPC we created earlier. For part 2: we switched to the custom VPC.
  vpc_id = aws_vpc.tf-workshop-vpc.id

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
    security_groups = [aws_security_group.load_balancer.id]
  }

  # Outgoing traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "load_balancer" {
  name        = "tf-workshop-lb-sg"
  vpc_id      = aws_vpc.tf-workshop-vpc.id

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

# We need this block to be able to use EC2 Instance Connect to connect to the instance we are creating.
data "aws_ec2_managed_prefix_list" "instance_connect" {
  name = "com.amazonaws.us-east-1.ec2-instance-connect"
}

# This data block is used to fetch the latest Ubuntu AMI from AWS.
data "aws_ami" "ubuntu" {
  most_recent = true
  # The owners field is set to the Canonical account ID (official publisher of Ubuntu AMIs).
  owners = ["099720109477"] # Canonical
  # The filter is used to specify the name of the AMI we want to fetch. 
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Now we create EC2 instances using the Ubuntu AMI we fetched earlier.
# The instance type is set to "t2.micro" which is eligible for the free tier.
resource "aws_instance" "web_server" {
  ami = data.aws_ami.ubuntu.id
  # The instance type is set to "t2.micro" which is free.
  instance_type = "t2.micro"
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

# A second webserver, because we were uncreative :D
resource "aws_instance" "web_server_2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  network_interface {
    network_interface_id = aws_network_interface.web-2.id
    device_index         = 0
  }

  user_data = file("${path.module}/install_apache.sh")

  depends_on = [
    aws_eip.webserver-2,
    aws_route_table_association.public-2
  ]

  tags = {
    Name = "webserver-2"
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

resource "aws_network_interface" "web-2" {
  subnet_id       = aws_subnet.public-2.id
  security_groups = [aws_security_group.terraform-ws-1.id]

  tags = {
    Name = "workshop-web-interface-2"
  }
}

# Now we are creating an Elastic IP and associating it with the ENI.
resource "aws_eip" "webserver" {
  domain            = "vpc"
  network_interface = aws_network_interface.web.id

  depends_on = [aws_internet_gateway.tf-igw]

  tags = {
    Name = "tf-workshop-web-eip"
  }
}

resource "aws_eip" "webserver-2" {
  domain            = "vpc"
  network_interface = aws_network_interface.web-2.id

  depends_on = [aws_internet_gateway.tf-igw]

  tags = {
    Name = "tf-workshop-web-eip-2"
  }
}

# Now we are creating the actual Load Balancer and associating it with the public subnets and security group.
resource "aws_elb" "lb" {
  name               = "tf-workshop-web-lb"
  internal           = false #accessible from the internet

  security_groups = [aws_security_group.load_balancer.id]

  # To know where to forward requests to
  instances = [
    aws_instance.web_server.id,
    aws_instance.web_server_2.id
  ]

  cross_zone_load_balancing = true

  subnets = [
    aws_subnet.public.id,
    aws_subnet.public-2.id
  ]

  depends_on = [
    aws_route_table_association.public,
    aws_route_table_association.public-2
  ]

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 80
    instance_protocol = "http"
  }

  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "tf-workshop-web-lb"
  }
}

# Creating outputs to display the public IP address of the web server and the URL of the website.
# The output will be seen in the terminal after running `terraform apply`.
output "public_ip" {
  description = "Public IP web server"
  value       = aws_eip.webserver.public_ip
}

output "website_url" {
  description = "URL"
  value       = "http://${aws_eip.webserver.public_ip}"
}

output "public_ip_2" {
  description = "Public IP web server 2"
  value       = "http://${aws_eip.webserver-2.public_ip}"
}

# Creating outputs to display the DNS address of the load balancer.
output "load_balancer_dns" {
  value = aws_elb.lb.dns_name
}

output "load_balancer_url" {
  value = "http://${aws_elb.lb.dns_name}"
}